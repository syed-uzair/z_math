const zqlite = @import("zqlite");
const std = @import("std");

const ZAppErrors = @import("../errors.zig").ZAppErrors;
const Allocator = std.mem.Allocator;
const sql = @import("./sql_query.zig");
const Expr = @import("./expr.zig").Expr;
const assert = @import("../assert/assert.zig");

const HOME_ENV = "HOME";

pub fn getDbPath(alloc: Allocator) ![:0]u8 {
    if (std.posix.getenv(HOME_ENV)) |home_env| {
        return try std.fmt.allocPrintZ(alloc, "{s}/z_math", .{home_env});
    }
    std.debug.print("{s} env not set\n", .{HOME_ENV});
    std.debug.print("Z_Math only supports the POSIX-compliant system.\n", .{});
    std.process.exit(1);
}

pub const DB = struct {
    const Self = @This();

    alloc: Allocator,

    conn: zqlite.Conn,
    path: [:0]u8,
    pub fn init(allocator: Allocator) !Self {
        const db_path = try getDbPath(allocator);
        const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
        var conn = try zqlite.open(db_path, flags);
        try createTable(&conn);

        return .{
            .conn = conn,
            .path = db_path,
            .alloc = allocator,
        };
    }
    pub fn deinit(self: *Self) void {
        self.conn.close();
        self.alloc.free(self.path);
    }

    pub fn delExpr(self: *Self, id: u64) void {
        self.conn.exec(sql.del_exper_query, .{id}) catch |err| {
            std.debug.print("[ERROR]: delEzprs#conn Code {any}\n", .{err});
            std.debug.print("[ERROR]: delEzprs#conn      {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };
    }
    pub fn delRangeExpr(self: *Self, from: u64, to: u64) void {
        assert.assert(from != 0, "DB::delRangeEzprs from cant be 0");
        assert.assert(from < to, "DB::delRangeEzprs From value needs to be grater then To");
        self.conn.exec(sql.del_range_exper_query, .{ from, to }) catch |err| {
            std.debug.print("[ERROR]: delRangeEzprs#conn Code {any}\n", .{err});
            std.debug.print("[ERROR]: delRangeEzprs#conn      {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };
    }
    pub fn delAllExpr(self: *Self) void {
        self.conn.exec(sql.del_all_exper_query, .{}) catch |err| {
            std.debug.print("[ERROR]: delAllEzprs#conn Code {any}\n", .{err});
            std.debug.print("[ERROR]: delAllEzprs#conn      {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };
    }
    pub fn addExpr(self: *Self, input: []const u8, output: []const u8, execut_id: u64) void {
        self.conn.exec(sql.add_exper_query, .{ input, output, execut_id }) catch |err| {
            std.debug.print("[ERROR]: getEzprs#conn Code {any}\n", .{err});
            std.debug.print("[ERROR]: getEzprs#conn      {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };
    }
    pub fn getAllExprs(self: *Self, order: sql.Order) ![]Expr {
        var result = std.ArrayList(Expr).init(self.alloc);
        var rows = self.conn.rows(try sql.allExpersQuery(order), .{}) catch {
            std.debug.print("[ERROR]: getAllEzprs#conn {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };

        defer rows.deinit();
        if (rows.err) |err| {
            std.debug.print("[ERROR]: getEzprs#rows {any}", .{err});
            std.process.exit(1);
        }
        while (rows.next()) |row| {
            const v = Expr{
                .id = row.int(0),
                .input = try self.alloc.dupe(u8, row.text(1)),
                .output = try self.alloc.dupe(u8, row.text(2)),
                .execution_id = try self.alloc.dupe(u8, row.text(3)),
                .created_at = try self.alloc.dupe(u8, row.text(4)),
            };
            try result.append(v);
        }
        return try result.toOwnedSlice();
    }
    /// Default Options for [getEzprs]
    /// Options
    ///  limit: u64 = 5,
    ///  order: Order = .DESC,
    pub fn getExprs(self: *Self, opt: sql.Options) ![]Expr {
        var result = std.ArrayList(Expr).init(self.alloc);
        var rows = self.conn.rows(try sql.expersQuery(opt), .{}) catch {
            std.debug.print("[ERROR]: getEzprs#conn {s}\n", .{self.conn.lastError()});
            std.process.exit(1);
        };

        defer rows.deinit();
        if (rows.err) |err| {
            std.debug.print("[ERROR]: getEzprs#rows {any}", .{err});
            std.process.exit(1);
        }
        while (rows.next()) |row| {
            const v = Expr{
                .id = row.int(0),
                .input = try self.alloc.dupe(u8, row.text(1)),
                .output = try self.alloc.dupe(u8, row.text(2)),
                .execution_id = try self.alloc.dupe(u8, row.text(3)),
                .created_at = try self.alloc.dupe(u8, row.text(4)),
            };
            try result.append(v);
        }
        return try result.toOwnedSlice();
    }

    fn createTable(conn: *zqlite.Conn) !void {
        conn.execNoArgs(sql.create_expression_table_query) catch {
            std.debug.print("{s}", .{sql.create_expression_table_query});
            std.debug.print("{s}", .{conn.lastError()});
            std.process.exit(1);
        };
        try conn.execNoArgs(sql.index_expression_query);
    }
};