//DataFrame is a 2-dimensional labeled data structure with columns of potentially different types. You can think of it like a spreadsheet or SQL table, or a dict of Series objects. It is generally the most commonly used pandas object.
//
const std = @import("std");
const meta = std.meta;
const ArrayList = std.ArrayList;
const TypeInfo = std.builtin.Type;
const print = std.debug.print;
const ParseError = error{ParseError} || anyerror;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();

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
        .Pointer => |ptr| {
            if (ptr.size == .Slice) {
                if (ptr.child == u8) {
                    return buffer;
                }
            }
        },
        else => {
            @compileError("Tried to parse an unsupported type: " ++ @typeName(T));
        },
    };
}

pub fn init_From_Pair(comptime T: type, a: anytype, b: anytype) T {
    var t = std.mem.zeroInit(T, a);
    inline for (@typeInfo(@TypeOf(b)).@"struct".fields) |field| {
        @field(t, field.name) = @field(b, field.name);
    }
    return t;
}

fn initSubset(comptime T: type, a: anytype) T {
    var t = std.mem.zeroInit(T, .{});
    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (@hasField(@TypeOf(a), field.name)) {
            @field(t, field.name) = @field(a, field.name);
        }
    }
    return t;
}

pub fn init_Series(comptime T: type) type {
    comptime {
        return struct {
            name: []const u8,
            data: ArrayList(T),
        };
    }
}

pub fn DataFrame(comptime ColumnLabels: type, comptime RowLabels: type) type {
    if (@typeInfo(RowLabels) != .@"struct") {
        @compileError("RowLabels must be a struct, not " ++ @typeName(ColumnLabels));
    }
    if (@typeInfo(ColumnLabels) != .@"struct") {
        @compileError("ColumnLabels must be a struct, not " ++ @typeName(RowLabels));
    }

    const rowFields = meta.fields(RowLabels);
    const columnFields = meta.fields(ColumnLabels);

    inline for (columnFields) |field| {
        if (@hasField(RowLabels, field.name)) {
            @compileError("ColumnLabels and RowLabels must not have the same field: " ++ field.name);
        }
    }

    const dataFields = rowFields ++ columnFields;

    return struct {
        data: DataArray,

        const Self = @This();
        const RowType = RowLabels;
        const ColumnType = ColumnLabels;
        const DataType = @Type(TypeInfo{ .@"struct" = .{ .layout = .auto, .fields = dataFields, .decls = &[0]TypeInfo.Declaration{}, .is_tuple = false } });

        const DataArray = std.ArrayList(DataType);

        pub fn init_Empty(allocator: std.mem.Allocator) !Self {
            const self = Self{
                .data = DataArray.init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        const FileError = error{ParseError} || anyerror;

        pub fn fromFile(allocator: *std.mem.Allocator, filename: []const u8) FileError!Self {
            var self = try Self.init_Empty(allocator.*);
            defer self.deinit();

            var file = try std.fs.cwd().openFile(filename, .{});
            defer file.close();

            var buf_reader = std.io.bufferedReader(file.reader());
            var reader = buf_reader.reader();

            //var buf: [1024]u8 = undefined;
            const max_length: usize = 1024;

            {
                const header = (try reader.readUntilDelimiterOrEofAlloc(allocator.*, '\n', max_length)) orelse return FileError.ParseError;
                defer allocator.free(header);

                var headerIter = std.mem.tokenize(u8, header, ",");

                inline for (columnFields) |field| {
                    const col = headerIter.next();
                    std.debug.assert(col != null);
                    std.debug.assert(std.mem.eql(u8, col.?, field.name));
                }
                std.debug.assert(headerIter.rest().len == 0);
            }

            while (try reader.readUntilDelimiterOrEofAlloc(allocator.*, '\n', max_length)) |line| {
                defer allocator.free(line);
                var lineIter = std.mem.tokenize(u8, line, ",");
                var entry = std.mem.zeroInit(ColumnLabels, .{});
                inline for (columnFields) |field| {
                    const cell = lineIter.next() orelse return FileError.ParseError;
                    const value = try parse(field.type, cell);
                    @field(entry, field.name) = value;
                }
                const index = std.mem.zeroInit(RowLabels, .{});
                try self.append(index, entry);
            }

            return self;
        }

        pub fn append(self: *Self, index: RowLabels, data: ColumnLabels) !void {
            const d = init_From_Pair(DataType, index, data);
            try self.data.append(d);
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;
            try writer.print("DataFrame [ ", .{});
            inline for (rowFields) |field| {
                try writer.print("{s}:{} ", .{ field.name, field.type });
            }
            try writer.print("] x [ ", .{});
            inline for (columnFields) |field| {
                try writer.print("{s}:{} ", .{ field.name, field.type });
            }
            try writer.print("] ({} rows) {{", .{self.data.items.len});

            if (self.data.items.len != 0) {
                try writer.print("\n", .{});
            }
            for (self.data.items, 0..) |row, index| {
                const r = initSubset(RowType, row);
                const c = initSubset(ColumnType, row);
                try writer.print("    {}: {} = {},\n", .{ index, r, c });
            }
            try writer.print("}}", .{});
        }
    };
}

pub fn main() !void {
    //var gpa2 = std.heap.GeneralPurposeAllocator(.{}){};
    //var gpa2_allocator = gpa2.allocator();
    //_ = gpa2_allocator;
    const Stats = struct {
        goals: u32,
        assists: u32,
        distanceRun: f32,
        wins: u32,
        losses: u32,
    };

    const Label = struct {};

    const DF = DataFrame(Label, Stats);

    var df = try DF.init_Empty(gpa_allocator);
    defer df.deinit();

    try df.append(.{ .goals = 10, .assists = 5, .distanceRun = 1000.0, .wins = 1, .losses = 0 }, .{});
    try df.append(.{ .goals = 2, .assists = 11, .distanceRun = 1212.0, .wins = 4, .losses = 1 }, .{});

    //inline for (meta.fields(DF.DataType)) |field| {
    //   print("field: {s}\n", .{field.name});
    //}
    //
    print("dataframe: {}\n", .{df});
}
