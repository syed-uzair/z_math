const std = @import("std");

var buf: [1024]u8 = undefined;

pub const Tabels = enum { Expressions };
pub const EXPR_TABLE: []const u8 = @tagName(Tabels.Expressions);

pub const create_expression_table_query =
    \\CREATE TABLE IF NOT EXISTS Expressions (
    \\id            INTEGER PRIMARY KEY,
    \\input         TEXT NOT NULL,
    \\output        TEXT NOT NULL,
    \\op_type       TEXT NOT NULL,
    \\execution_id  INTEGER NOT NULL,
    \\created_at    TEXT DEFAULT CURRENT_TIMESTAMP);
;

pub const index_expression_query = "CREATE INDEX IF NOT EXISTS idx_execution_id ON Expressions (execution_id);";
pub const index_op_type_query = "CREATE INDEX IF NOT EXISTS idx_op_type ON Expressions (op_type);";

pub const Order = enum { DESC, ASC };
pub const Options = struct {
    limit: u64 = 5,
    order: Order = .DESC,
};
pub fn allExpersQuery(order: Order) ![]const u8 {
    return try std.fmt.bufPrint(&buf, "SELECT * FROM Expressions ORDER BY id {s};", .{@tagName(order)});
}
pub fn expersQuery(opt: Options) ![]const u8 {
    return try std.fmt.bufPrint(&buf, "SELECT * FROM (SELECT * FROM Expressions ORDER BY id {s} LIMIT {d} ) ORDER BY id;", .{ @tagName(opt.order), opt.limit });
}
pub fn expersQueryWhere(opt: Options, where: []const u8) ![]const u8 {
    return try std.fmt.bufPrint(&buf, "SELECT * FROM (SELECT * FROM Expressions WHERE op_type = {s} ORDER BY id {s} LIMIT {d} ) ORDER BY id;", .{ where, @tagName(opt.order), opt.limit });
}
pub const add_exper_query = "INSERT INTO Expressions (input, output, op_type ,execution_id) VALUES (?1, ?2, ?3, ?4);";

pub const del_exper_query = "DELETE FROM Expressions WHERE id = ?1;";
pub const del_all_exper_query = "DELETE FROM Expressions;";
pub const del_range_exper_query = "DELETE FROM Expressions WHERE id BETWEEN ?1 AND ?2;";
