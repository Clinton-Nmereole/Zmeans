const std = @import("std");
const print = std.debug.print;
const rand = std.crypto.random;
const math = std.math;
const kmeans = @import("kmeans.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();

pub fn main() !void {
    var means = kmeans.get_means(kmeans.Point, 3, kmeans.dataset[0..]);
    var clusters = try kmeans.init_clusters(kmeans.Point, 3, gpa_allocator);
    const group = try kmeans.assign_cluster(kmeans.Point, kmeans.dataset[0..], means[0..], clusters);
    for (group, 0..) |c, i| {
        print("cluster {d}: {any}\n \n", .{ i + 1, c.items });
    }
    var new_means = try kmeans.new_centroids(kmeans.Point, 3, group);
    print("new means: {d:.2}\n \n", .{new_means});

    //HACK: This is disgusting, but it works.
    for (0..clusters.len) |i| {
        clusters[i].deinit();
    }
    clusters = try kmeans.init_clusters(kmeans.Point, 3, gpa_allocator);
    const new_group = try kmeans.assign_cluster(kmeans.Point, kmeans.dataset[0..], new_means[0..], clusters);
    for (new_group, 0..) |c, i| {
        print("new cluster {d}: {any}\n \n", .{ i + 1, c.items });
    }

    var new_new_means = try kmeans.new_centroids(kmeans.Point, 3, new_group);
    print("new new means: {d:.2}\n \n", .{new_new_means});

    for (0..clusters.len) |i| {
        clusters[i].deinit();
    }

    clusters = try kmeans.init_clusters(kmeans.Point, 3, gpa_allocator);
    const new_new_group = try kmeans.assign_cluster(kmeans.Point, kmeans.dataset[0..], new_new_means[0..], clusters);
    for (new_new_group, 0..) |c, i| {
        print("new new cluster {d}: {any}\n \n", .{ i + 1, c.items });
    }
}
