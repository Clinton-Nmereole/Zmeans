const std = @import("std");
const print = std.debug.print;
const rand = std.crypto.random;
const math = std.math;

//Utility functions
pub fn inSlice(comptime T: type, haystack: []const T, needle: T) bool {
    const typeInfo = @typeInfo(T);
    for (haystack) |thing| {
        switch (typeInfo) {
            .int, .float, .bool, .@"enum" => {
                if (thing == needle) {
                    return true;
                }
            },
            .@"struct" => {
                if (std.meta.eql(thing, needle)) {
                    return true;
                }
            },
            else => {
                @compileError("Tried to compare an unsupported type: " ++ @typeName(T));
            },
        }
    }
    return false;
}

// This function takes in an array with some number type (int or float) and returns the sum of all the elements in the array
pub fn sumArray(comptime T: type, haystack: []const T) !T {
    const typeInfo = @typeInfo(T);
    var sum: T = 0;
    switch (typeInfo) {
        .int, .float => {
            for (haystack) |thing| {
                sum += thing;
            }
            return sum;
        },
        else => {
            @compileError("Tried to sum an unsupported type: " ++ @typeName(T));
        },
    }
    return error.UnsupportedType;
}

pub fn closest(haystack: []const f32, needle: f32) usize {
    var idx: usize = 0;
    var currentClosest: f32 = math.floatMax(f32);
    for (haystack, 0..) |thing, i| {
        if (math.sqrt(math.pow(f32, needle - thing, 2)) < currentClosest) {
            currentClosest = math.sqrt(math.pow(f32, needle - thing, 2));
            idx = i;
        }
    }
    return idx;
}

//Point type
pub const Point = struct {
    x: f32,
    y: f32,

    pub fn format(value: Point, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("({d:.3}, {d:.3})", .{ value.x, value.y });
    }
};

pub fn euclidean_distance(a: Point, b: Point) f32 {
    return math.sqrt(math.pow(f32, a.x - b.x, 2) + math.pow(f32, a.y - b.y, 2));
}

pub fn closest_point(haystack: []const Point, needle: Point) usize {
    var idx: usize = 0;
    var currentClosest: f32 = math.floatMax(f32);
    for (haystack, 0..) |thing, i| {
        if (euclidean_distance(needle, thing) < currentClosest) {
            currentClosest = euclidean_distance(needle, thing);
            idx = i;
        }
    }
    return idx;
}

pub fn sum_Points(haystack: []const Point) Point {
    var sum: Point = .{ .x = 0, .y = 0 };
    for (haystack) |thing| {
        sum.x += thing.x;
        sum.y += thing.y;
    }
    return sum;
}

//Dummy dataset
pub const dataset = [_]Point{
    .{ .x = 1.0, .y = 2.0 },
    .{ .x = 2.0, .y = 3.0 },
    .{ .x = 3.0, .y = 4.0 },
    .{ .x = 4.0, .y = 5.0 },
    .{ .x = 5.0, .y = 6.0 },
    .{ .x = 6.0, .y = 7.0 },
    .{ .x = 7.0, .y = 8.0 },
    .{ .x = 8.0, .y = 9.0 },
    .{ .x = 9.0, .y = 10.0 },
    .{ .x = 10.0, .y = 11.0 },
    .{ .x = 11.0, .y = 12.0 },
    .{ .x = 12.0, .y = 13.0 },
    .{ .x = 17.4, .y = 11.2 },
    .{ .x = 13.7, .y = 19.2 },
    .{ .x = 21.4, .y = 2.11 },
    .{ .x = 7.9, .y = 22.7 },
    .{ .x = 11.21, .y = 9.6 },
    .{ .x = 11.2, .y = 12.7 },
    .{ .x = 20.4, .y = 7.9 },
    .{ .x = 5.2, .y = 13.7 },
    .{ .x = 11.2, .y = 19.2 },
    .{ .x = 11.2, .y = 22.7 },
    .{ .x = 11.2, .y = 9.6 },
    .{ .x = 11.2, .y = 12.7 },
    .{ .x = 11.2, .y = 7.9 },
    .{ .x = 11.2, .y = 13.7 },
};

//Random Partition Kmeans Algorithm
//get the first random centroids of the dataset
pub fn get_means(comptime T: type, comptime k: usize, data: []const T) [k]T {
    var means: [k]T = undefined;
    for (0..k) |i| {
        var cluster = data[rand.uintAtMost(usize, data.len - 1)];
        while (inSlice(T, &means, cluster)) {
            cluster = data[rand.uintAtMost(usize, data.len - 1)];
        }
        means[i] = cluster;
    }
    print("means: {any}\n", .{means});
    return means;
}

//Make k clusters
pub fn init_clusters(comptime T: type, comptime k: usize, comptime allocator: std.mem.Allocator) ![]std.ArrayList(T) {
    var clusters = try allocator.alloc(std.ArrayList(T), k);
    for (0..k) |i| {
        clusters[i] = std.ArrayList(T).init(allocator);
    }
    return clusters;
}

//Assign each data point to a cluster
pub fn assign_cluster(comptime T: type, comptime data: []const T, means: []const T, clusters: []std.ArrayList(T)) ![]std.ArrayList(T) {
    //print("means: {d:.2}\n", .{means});
    for (data) |d| {
        //print("means in loop: {d:.2}\n", .{means});
        const group = closest_point(means, d);
        try clusters[group].append(d);
    }
    return clusters;
}

pub fn new_centroids(comptime T: type, comptime k: usize, clusters: []std.ArrayList(T)) ![k]T {
    var new_means: [k]T = undefined;
    for (clusters, 0..) |c, i| {
        const cluster_sum = sum_Points(c.items);
        new_means[i] = .{ .x = cluster_sum.x / @as(f32, @floatFromInt(c.items.len)), .y = cluster_sum.y / @as(f32, @floatFromInt(c.items.len)) };
    }
    return new_means;
}
