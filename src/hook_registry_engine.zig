const std = @import("std");
const primitives = @import("hook_primitives.zig");

pub const HookPhase = primitives.HookPhase;
pub const HookError = primitives.HookError;

pub fn Hook(comptime ContextType: type, comptime DataType: type) type {
    return struct {
        name: []const u8,
        priority: i16,
        callback: *const fn (ctx: *ContextType, data: DataType) HookError!void,
    };
}

pub fn HookRegistry(comptime ContextType: type, comptime DataType: type) type {
    const HookT = Hook(ContextType, DataType);

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        pre_observe: std.ArrayListUnmanaged(HookT),
        post_observe: std.ArrayListUnmanaged(HookT),
        pre_mutate: std.ArrayListUnmanaged(HookT),
        post_mutate: std.ArrayListUnmanaged(HookT),
        pre_results: std.ArrayListUnmanaged(HookT),
        post_results: std.ArrayListUnmanaged(HookT),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .pre_observe = .{},
                .post_observe = .{},
                .pre_mutate = .{},
                .post_mutate = .{},
                .pre_results = .{},
                .post_results = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.pre_observe.deinit(self.allocator);
            self.post_observe.deinit(self.allocator);
            self.pre_mutate.deinit(self.allocator);
            self.post_mutate.deinit(self.allocator);
            self.pre_results.deinit(self.allocator);
            self.post_results.deinit(self.allocator);
        }

        pub fn register(self: *Self, phase: HookPhase, hook: HookT) !void {
            const list = self.listForPhase(phase);

            var insert_idx: usize = list.items.len;
            for (list.items, 0..) |existing, i| {
                if (hook.priority < existing.priority) {
                    insert_idx = i;
                    break;
                }
            }

            try list.insert(self.allocator, insert_idx, hook);
        }

        pub fn execute(self: *Self, phase: HookPhase, ctx: *ContextType, data: DataType) HookError!void {
            const list = self.listForPhase(phase);

            for (list.items) |hook| {
                hook.callback(ctx, data) catch |err| {
                    std.log.warn("Hook '{s}' failed in {s}: {s}", .{ hook.name, @tagName(phase), @errorName(err) });
                    return HookError.HookFailed;
                };
            }
        }

        pub fn countForPhase(self: *const Self, phase: HookPhase) usize {
            return switch (phase) {
                .pre_observe => self.pre_observe.items.len,
                .post_observe => self.post_observe.items.len,
                .pre_mutate => self.pre_mutate.items.len,
                .post_mutate => self.post_mutate.items.len,
                .pre_results => self.pre_results.items.len,
                .post_results => self.post_results.items.len,
            };
        }

        fn listForPhase(self: *Self, phase: HookPhase) *std.ArrayListUnmanaged(HookT) {
            return switch (phase) {
                .pre_observe => &self.pre_observe,
                .post_observe => &self.post_observe,
                .pre_mutate => &self.pre_mutate,
                .post_mutate => &self.post_mutate,
                .pre_results => &self.pre_results,
                .post_results => &self.post_results,
            };
        }
    };
}

test "HookRegistry engine: priority ordering" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        allocator: std.mem.Allocator,
        order: std.ArrayListUnmanaged(u8) = .{},

        fn deinit(self: *@This()) void {
            self.order.deinit(self.allocator);
        }
    };

    const TestData = struct {
        value: u8,
    };

    const Registry = HookRegistry(TestContext, TestData);
    const HookT = Hook(TestContext, TestData);
    var registry = Registry.init(allocator);
    defer registry.deinit();

    var test_ctx = TestContext{ .allocator = allocator };
    defer test_ctx.deinit();

    const Hooks = struct {
        fn first(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 1);
        }
        fn second(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 2);
        }
        fn third(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 3);
        }
    };

    try registry.register(.pre_observe, HookT{ .name = "third", .priority = 100, .callback = Hooks.third });
    try registry.register(.pre_observe, HookT{ .name = "first", .priority = -100, .callback = Hooks.first });
    try registry.register(.pre_observe, HookT{ .name = "second", .priority = 0, .callback = Hooks.second });

    try registry.execute(.pre_observe, &test_ctx, .{ .value = 0 });

    try std.testing.expectEqual(@as(usize, 3), test_ctx.order.items.len);
    try std.testing.expectEqual(@as(u8, 1), test_ctx.order.items[0]);
    try std.testing.expectEqual(@as(u8, 2), test_ctx.order.items[1]);
    try std.testing.expectEqual(@as(u8, 3), test_ctx.order.items[2]);
}

test "HookRegistry engine: callback failure is propagated as HookFailed" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        allocator: std.mem.Allocator,
        order: std.ArrayListUnmanaged(u8) = .{},

        fn deinit(self: *@This()) void {
            self.order.deinit(self.allocator);
        }
    };

    const TestData = struct {
        value: u8,
    };

    const Registry = HookRegistry(TestContext, TestData);
    const HookT = Hook(TestContext, TestData);
    var registry = Registry.init(allocator);
    defer registry.deinit();

    var test_ctx = TestContext{ .allocator = allocator };
    defer test_ctx.deinit();

    const Hooks = struct {
        fn ok(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 1);
        }
        fn fail(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 2);
            return HookError.HookFailed;
        }
        fn should_not_run(ctx: *TestContext, data: TestData) HookError!void {
            _ = data;
            try ctx.order.append(ctx.allocator, 3);
        }
    };

    try registry.register(.pre_observe, HookT{ .name = "ok", .priority = -100, .callback = Hooks.ok });
    try registry.register(.pre_observe, HookT{ .name = "fail", .priority = 0, .callback = Hooks.fail });
    try registry.register(.pre_observe, HookT{ .name = "later", .priority = 100, .callback = Hooks.should_not_run });

    try std.testing.expectError(HookError.HookFailed, registry.execute(.pre_observe, &test_ctx, .{ .value = 0 }));
    try std.testing.expectEqual(@as(usize, 2), test_ctx.order.items.len);
    try std.testing.expectEqual(@as(u8, 1), test_ctx.order.items[0]);
    try std.testing.expectEqual(@as(u8, 2), test_ctx.order.items[1]);
}
