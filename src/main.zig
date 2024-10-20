const std = @import("std");
const pgzx = @import("pgzx");
const pg = pgzx.c;
const tb = @cImport({
    @cInclude("./tb_client.h");
});

comptime {
    pgzx.PG_MODULE_MAGIC();

    pgzx.PG_FUNCTION_V1("lookup_account", lookup_account);
    pgzx.PG_FUNCTION_V1("query_by_id", query_by_id);
}

pub export fn _PG_init() void {
    pgzx.elog.options.postgresLogFnLeven = pg.LOG;
    std.log.debug("pg_tigerbeetle: init...\n", .{});
}

var tbClient: tb.tb_client_t = null;
var id: u128 = 1;

var sync_mutex = std.Thread.Mutex{};
var sync_condition = std.Thread.Condition{};
var sync_result_bytes: [(1024 * 1024) - 256]u8 = undefined;
var sync_result: struct {
    result_ptr: ?[*]const u8,
    result_len: u32,
} = undefined;

fn on_complete(
    _: usize,
    _: tb.tb_client_t,
    _: [*c]tb.tb_packet_t,
    bytes: [*c]const u8,
    result_len: u32,
) callconv(.C) void {
    sync_mutex.lock();
    @memcpy(sync_result_bytes[0..result_len], bytes[0..result_len]);
    sync_result = .{
        .result_len = result_len,
        .result_ptr = &sync_result_bytes,
    };
    sync_mutex.unlock();
    sync_condition.signal();
}

fn getClient() void
{
    const address: []const u8 = "127.0.0.1:3000";

    if (tbClient == null) {
        const status = tb.tb_client_init(&tbClient, 0, address.ptr,  address.len, 0, &on_complete);
        if (status != 0)
            {
                pgzx.elog.Info(@src(), "errro connecting:\t{}\n", .{status});
            }
    }
}

fn lookup_account() ![:0]const u8 {
    getClient();

    var memctx = try pgzx.mem.createAllocSetContext("pg_tigerbeetle_zig_context", .{ .parent = pg.CurrentMemoryContext });
    const alloctor: std.mem.Allocator = memctx.allocator();

    const p: *tb.tb_packet_t = try alloctor.create(tb.tb_packet_t);
    p.operation = 131;
    p.status = 0;
    p.data_size = 16;
    p.data = @ptrCast(&id);
    tb.tb_client_submit(tbClient, p);
    sync_mutex.lock();
    defer sync_mutex.unlock();
    sync_condition.wait(&sync_mutex);

    const acc = std.mem.bytesAsValue(tb.tb_account_t, sync_result_bytes[0..128]);

    pgzx.elog.Info(@src(), "account: {}", .{acc});

    return "Hello, world!";
}

fn query_by_id(xid: u32) ![]const u8 {
    var newId: u128 = @as(u128, xid);
    pgzx.elog.Info(@src(), "id: {}", .{newId});

    getClient();

    var memctx = try pgzx.mem.createAllocSetContext("pg_tigerbeetle_zig_context", .{ .parent = pg.CurrentMemoryContext });
    const alloctor: std.mem.Allocator = memctx.allocator();

    const p: *tb.tb_packet_t = try alloctor.create(tb.tb_packet_t);
    p.operation = 131;
    p.status = 0;
    p.data_size = 16;
    p.data = @ptrCast(&newId);
    tb.tb_client_submit(tbClient, p);
    sync_mutex.lock();
    defer sync_mutex.unlock();
    sync_condition.wait(&sync_mutex);

    const acc = std.mem.bytesAsValue(tb.tb_account_t, sync_result_bytes[0..128]);

    if(acc.id == 0) {
        pgzx.elog.Info(@src(), "account not found", .{});
        return "";
    }


    pgzx.elog.Info(@src(), "account: {}", .{acc});

    return "";
}