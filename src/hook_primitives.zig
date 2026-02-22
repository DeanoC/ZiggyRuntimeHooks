const std = @import("std");

pub const HookPhase = enum {
    pre_observe,
    post_observe,
    pre_mutate,
    post_mutate,
    pre_results,
    post_results,
};

pub const HookError = error{
    HookFailed,
    InvalidPhase,
    OutOfMemory,
};

pub const HookPriority = enum(i16) {
    system_first = -1000,
    normal = 0,
    system_last = 1000,
};

pub const CoreEntry = struct {
    key: []const u8,
    value: []const u8,
    mutable: bool = true,
};

pub const RomEntry = CoreEntry;

pub const CorePrompt = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMapUnmanaged(CoreEntry),

    pub fn init(allocator: std.mem.Allocator) CorePrompt {
        return .{
            .allocator = allocator,
            .entries = .{},
        };
    }

    pub fn deinit(self: *CorePrompt) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn set(self: *CorePrompt, key: []const u8, value: []const u8) !void {
        if (self.entries.getEntry(key)) |existing| {
            const old_value = existing.value_ptr.value;
            const new_value = try self.allocator.dupe(u8, value);
            existing.value_ptr.value = new_value;
            self.allocator.free(old_value);
            return;
        }

        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        try self.entries.put(self.allocator, owned_key, .{
            .key = owned_key,
            .value = owned_value,
            .mutable = true,
        });
    }

    pub fn get(self: *const CorePrompt, key: []const u8) ?[]const u8 {
        const entry = self.entries.get(key) orelse return null;
        return entry.value;
    }

    pub fn has(self: *const CorePrompt, key: []const u8) bool {
        return self.entries.contains(key);
    }

    pub fn keys(self: *const CorePrompt, allocator: std.mem.Allocator) ![][]const u8 {
        var result = std.ArrayList([]const u8).init(allocator);
        errdefer result.deinit();

        var it = self.entries.keyIterator();
        while (it.next()) |key| {
            try result.append(key.*);
        }

        return result.toOwnedSlice();
    }
};

pub const Rom = CorePrompt;

pub const PendingTools = struct {
    tools: std.ArrayListUnmanaged(ToolCall),

    pub const ToolCall = struct {
        name: []const u8,
        args_json: []const u8,
    };

    pub fn init() PendingTools {
        return .{ .tools = .{} };
    }

    pub fn deinit(self: *PendingTools, allocator: std.mem.Allocator) void {
        for (self.tools.items) |*tool| {
            allocator.free(tool.name);
            allocator.free(tool.args_json);
        }
        self.tools.deinit(allocator);
    }

    pub fn add(self: *PendingTools, allocator: std.mem.Allocator, name: []const u8, args_json: []const u8) !void {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_args = try allocator.dupe(u8, args_json);
        errdefer allocator.free(owned_args);

        try self.tools.append(allocator, .{
            .name = owned_name,
            .args_json = owned_args,
        });
    }
};

test "Rom: set and get" {
    const allocator = std.testing.allocator;
    var rom = Rom.init(allocator);
    defer rom.deinit();

    try rom.set("key1", "value1");
    try std.testing.expectEqualStrings("value1", rom.get("key1").?);
    try rom.set("key1", "value2");
    try std.testing.expectEqualStrings("value2", rom.get("key1").?);
    try std.testing.expect(rom.get("missing") == null);
}

test "PendingTools: add and deinit" {
    const allocator = std.testing.allocator;
    var pending = PendingTools.init();
    defer pending.deinit(allocator);

    try pending.add(allocator, "tool_a", "{\"x\":1}");
    try std.testing.expectEqual(@as(usize, 1), pending.tools.items.len);
    try std.testing.expectEqualStrings("tool_a", pending.tools.items[0].name);
}
