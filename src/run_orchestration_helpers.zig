const std = @import("std");

pub const OperationClass = enum {
    chat,
    control,
};

pub fn isChatLikeControlAction(action: ?[]const u8) bool {
    const control_action = action orelse "state";
    return std.mem.eql(u8, control_action, "goal") or std.mem.eql(u8, control_action, "plan");
}

pub fn operationTimeoutNs(
    chat_operation_timeout_ms: u64,
    control_operation_timeout_ms: u64,
    operation_class: OperationClass,
) u64 {
    const timeout_ms = switch (operation_class) {
        .chat => chat_operation_timeout_ms,
        .control => control_operation_timeout_ms,
    };
    return timeout_ms * std.time.ns_per_ms;
}

pub const RunStepTracker = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    active_run_steps: std.StringHashMapUnmanaged(void) = .{},
    cancelled_run_steps: std.StringHashMapUnmanaged(void) = .{},

    pub fn init(allocator: std.mem.Allocator) RunStepTracker {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RunStepTracker) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active_it = self.active_run_steps.iterator();
        while (active_it.next()) |entry| self.allocator.free(entry.key_ptr.*);
        self.active_run_steps.deinit(self.allocator);

        var cancelled_it = self.cancelled_run_steps.iterator();
        while (cancelled_it.next()) |entry| self.allocator.free(entry.key_ptr.*);
        self.cancelled_run_steps.deinit(self.allocator);
    }

    pub fn markRunStepActive(self: *RunStepTracker, run_id: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.active_run_steps.contains(run_id)) return false;
        const owned_key = try self.allocator.dupe(u8, run_id);
        errdefer self.allocator.free(owned_key);
        try self.active_run_steps.put(self.allocator, owned_key, {});
        return true;
    }

    pub fn isRunStepActive(self: *RunStepTracker, run_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.active_run_steps.contains(run_id);
    }

    pub fn clearRunStepTracking(self: *RunStepTracker, run_id: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.active_run_steps.fetchRemove(run_id)) |entry| self.allocator.free(entry.key);
        if (self.cancelled_run_steps.fetchRemove(run_id)) |entry| self.allocator.free(entry.key);
    }

    pub fn requestActiveRunStepCancel(self: *RunStepTracker, run_id: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.active_run_steps.contains(run_id)) return false;
        if (!self.cancelled_run_steps.contains(run_id)) {
            const owned_key = try self.allocator.dupe(u8, run_id);
            errdefer self.allocator.free(owned_key);
            try self.cancelled_run_steps.put(self.allocator, owned_key, {});
        }
        return true;
    }

    pub fn isRunStepCancelRequested(self: *RunStepTracker, run_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.cancelled_run_steps.contains(run_id);
    }

    pub fn isExecutionCancelled(self: *RunStepTracker, job_cancelled: bool, run_id: ?[]const u8) bool {
        if (job_cancelled) return true;
        if (run_id) |value| return self.isRunStepCancelRequested(value);
        return false;
    }
};

test "run_orchestration_helpers: chat-like control actions" {
    try std.testing.expect(isChatLikeControlAction("goal"));
    try std.testing.expect(isChatLikeControlAction("plan"));
    try std.testing.expect(!isChatLikeControlAction("state"));
    try std.testing.expect(!isChatLikeControlAction(null));
}

test "run_orchestration_helpers: timeout policy selects class timeout" {
    try std.testing.expectEqual(@as(u64, 120 * std.time.ns_per_ms), operationTimeoutNs(120, 10, .chat));
    try std.testing.expectEqual(@as(u64, 10 * std.time.ns_per_ms), operationTimeoutNs(120, 10, .control));
}

test "run_step_tracker: active cancel clear lifecycle" {
    const allocator = std.testing.allocator;
    var tracker = RunStepTracker.init(allocator);
    defer tracker.deinit();

    try std.testing.expect(try tracker.markRunStepActive("run-1"));
    try std.testing.expect(!try tracker.markRunStepActive("run-1"));
    try std.testing.expect(tracker.isRunStepActive("run-1"));

    try std.testing.expect(try tracker.requestActiveRunStepCancel("run-1"));
    try std.testing.expect(tracker.isRunStepCancelRequested("run-1"));
    try std.testing.expect(tracker.isExecutionCancelled(false, "run-1"));

    tracker.clearRunStepTracking("run-1");
    try std.testing.expect(!tracker.isRunStepActive("run-1"));
    try std.testing.expect(!tracker.isRunStepCancelRequested("run-1"));
    try std.testing.expect(!tracker.isExecutionCancelled(false, "run-1"));
}

test "run_step_tracker: cancel requests require active run step" {
    const allocator = std.testing.allocator;
    var tracker = RunStepTracker.init(allocator);
    defer tracker.deinit();

    try std.testing.expect(!try tracker.requestActiveRunStepCancel("inactive"));
    try std.testing.expect(!tracker.isRunStepCancelRequested("inactive"));
    try std.testing.expect(tracker.isExecutionCancelled(true, null));
}
