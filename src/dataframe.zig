//DataFrame is a 2-dimensional labeled data structure with columns of potentially different types. You can think of it like a spreadsheet or SQL table, or a dict of Series objects. It is generally the most commonly used pandas object.
//
const std = @import("std");
const meta = std.meta;
const ArrayList = std.ArrayList;
const TypeInfo = std.builtin.Type;
const print = std.debug.print;
const ParseError = error{ParseError} || anyerror;

//Parse a string into a type
pub fn parse(comptime T: type, buffer: []const u8) ParseError!T {
    const typeInfo = @typeInfo(T);
    return switch (typeInfo) {
        .Int => std.fmt.parseInt(T, buffer, 10),
        .Float => std.fmt.parseFloat(T, buffer),
        .Enum => |e| {
            inline for (e.fields) |field| {
                if (std.mem.eql(u8, field.name, buffer)) {
                    return @as(T, @enumFromInt(field.value));
                }
            }
            return ParseError.ParseError;
        },
        .Bool => std.mem.eql(u8, buffer, "true"),
        else => {
            @compileError("Tried to parse an unsupported type: " ++ @typeName(T));
        },
    };
}

pub fn init_ColumnLabels(comptime ColumnLabels: type) []const TypeInfo.StructField {
    return meta.fields(ColumnLabels);
}

pub fn Row(a: anytype) type {
    return struct {
        data: ArrayList(a),
    };
}

pub fn main() !void {
    const Player = struct {
        age: u8,
        goals: u8,
        team: []const u8,
        distance: f16,
    };

    const cols = init_ColumnLabels(Player);
    comptime var i = 0;
    inline while (i < cols.len) : (i += 1) {
        print("field {d}: {s}\n", .{ i, cols[i].name });
    }
}
