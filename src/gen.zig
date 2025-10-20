//! Writes CODATA recommended value constants based on NIST definitions txt files.
//!
//! Thank you to @Deecellar for parsing contributions

const std = @import("std");

const Record = struct {
    name: []const u8,
    value: f64,
    is_exact: bool,
    uncertainty: ?f64,
    unit: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const galloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(galloc);
    defer arena.deinit();
    const a = arena.allocator();

    var args = std.process.args();
    _ = args.next(); // Skip running binary name

    const codata_src = args.next() orelse "data/CODATA_2022_adjustment.txt";
    const output_path = args.next() orelse "src/codata.zig";

    std.debug.print("Generating CODATA constants (src={s}) → {s}\n", .{ codata_src, output_path });

    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(galloc);

    // input CODATA txt file
    const in = try std.fs.cwd().openFile(codata_src, .{ .mode = .read_only });
    defer in.close();

    var in_buf: [1024]u8 = undefined;
    var in_reader = in.reader(&in_buf);
    const stdin: *std.Io.Reader = &in_reader.interface;

    try parseCodata(a, stdin, &records, galloc);
    try writeConstants(records, output_path);
}

/// Stream and parse file lines into structured data.
fn parseCodata(
    arena: std.mem.Allocator,
    reader: *std.Io.Reader,
    out: *std.ArrayList(Record),
    galloc: std.mem.Allocator,
) !void {
    var allocating_writer = std.Io.Writer.Allocating.init(arena);

    while (reader.streamDelimiter(&allocating_writer.writer, '\n')) |_| {
        const line = allocating_writer.written();

        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue;

        try parseLine(out, trimmed, galloc);

        allocating_writer.clearRetainingCapacity();
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.print("an error occured: {any}\n", .{err}),
    }
}

/// Parse file line into structured data.
fn parseLine(out: *std.ArrayList(Record), line: []const u8, galloc: std.mem.Allocator) !void {
    // Split line by columns
    const name_txt, const rest1 = splitAtGap(line) orelse return;
    const value_txt, const rest2 = splitAtGap(rest1) orelse @panic("Null split");
    const uncert_txt, const unit = splitAtGap(rest2) orelse .{ rest2, "" };

    // sanitize name
    const name_norm = try sanitizeNameForConstant(name_txt, galloc);

    // parse value float
    const value_norm = try sanitizeNumberToken(value_txt, galloc);
    const value_float = std.fmt.parseFloat(f64, value_norm) catch @panic("Null value");

    // parse uncertantry float or exact measurment
    const is_exact = std.mem.eql(u8, uncert_txt, "(exact)");
    const uncert_norm = if (is_exact) "" else try sanitizeNumberToken(uncert_txt, galloc);

    const uncert_num: ?f64 = if (!is_exact and uncert_norm.len != 0)
        std.fmt.parseFloat(f64, uncert_norm) catch null
    else
        null;

    try out.append(galloc, Record{
        .name = name_norm,
        .value = value_float,
        .is_exact = is_exact,
        .uncertainty = uncert_num,
        .unit = unit,
    });
}

/// Split into columns by runs of ≥2 spaces.
fn splitAtGap(s: []const u8) ?([2][]const u8) {
    var i: usize = 0;
    while (i + i < s.len) : (i += 1) {
        if (s[i] == ' ' and s[i + 1] == ' ') {
            var j = i;
            while (j < s.len and s[j] == ' ') : (j += 1) {}
            const left = std.mem.trimRight(u8, s[0..i], s[s.len..]);
            const right = if (j < s.len) s[j..] else s[s.len..];
            return .{ left, right };
        }
    }
    return null;
}

test "split gap" {
    const s: []const u8 = "hello world         10.235 e-7";

    const text1, const text2 = splitAtGap(s) orelse @panic("Null split");
    try std.testing.expectEqualStrings("hello world", text1);
    try std.testing.expectEqualStrings("10.235 e-7", text2);
}

/// Sanitizes titles to match zig varible name formatting.
fn sanitizeNameForConstant(token: []const u8, galloc: std.mem.Allocator) ![]u8 {
    const trimmed = std.mem.trim(u8, token, " ");
    var buf = try galloc.dupe(u8, trimmed);

    var n: usize = 0;
    var i: usize = 0;
    while (i < buf.len) {
        var c = buf[i];
        if (c == ' ' or c == '-' or c == '/') {
            c = '_';
        }

        if (c >= 'A' and c <= 'Z') {
            c += 32; // 'A' -> 'a'
        }

        if (c == '.' or c == '(' or c == ')' or c == ',') {
            i += 1;
            continue;
        }

        std.debug.assert(n < buf.len);
        buf[n] = c;
        n += 1;
        i += 1;
    }
    return buf[0..n];
}

test "sanitize dirty name" {
    const token: []const u8 = "proton gyromag. ratio in MHz/T";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const galloc = gpa.allocator();
    const sanitizedToken = try sanitizeNameForConstant(token, galloc);

    try std.testing.expectEqualStrings("proton_gyromag_ratio_in_mhz_t", sanitizedToken);
}

/// Normalize numeric tokens:
/// - remove internal spaces
/// - trim trailing "..."
fn sanitizeNumberToken(token: []const u8, galloc: std.mem.Allocator) ![]u8 {
    const trimmed = std.mem.trim(u8, token, " ");
    var buf = try galloc.dupe(u8, trimmed);

    var n: usize = 0;
    var i: usize = 0;
    while (i < buf.len) {
        const c = buf[i];
        if (c == ' ') {
            i += 1;
            continue;
        }

        if (c == '.' and i + 2 < buf.len and std.mem.eql(u8, buf[i .. i + 3], "...")) {
            i += 3;
            continue;
        }

        std.debug.assert(n < buf.len);
        buf[n] = c;
        n += 1;
        i += 1;
    }
    return buf[0..n];
}

test "sanitize dirty float" {
    const token: []const u8 = "1.660 539 068 92... e-27";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const galloc = gpa.allocator();

    const sanitizedToken = try sanitizeNumberToken(token, galloc);
    const parsedToken = std.fmt.parseFloat(f64, sanitizedToken) catch @panic("Failed to parse");

    try std.testing.expectEqual(1.66053906892e-27, parsedToken);
}

/// Generate zig constants file based on parsed structured data.
fn writeConstants(records: std.ArrayList(Record), filename: [:0]const u8) !void {
    const out = try std.fs.cwd().createFile(filename, .{});
    defer out.close();

    var out_buf: [1024]u8 = undefined;
    var out_writter: std.fs.File.Writer = out.writer(&out_buf);
    const stdout: *std.Io.Writer = &out_writter.interface;

    try stdout.print("// This file is auto-generated from the CODATA source.\n// Do not edit manually — run src/gen.zig to regenerate.\n\n", .{});

    for (records.items[0..]) |r| {
        if (r.unit.len > 0) try stdout.print("/// unit: {s}\n", .{r.unit});
        if (r.is_exact) try stdout.print("/// is_exact: {any}\n", .{r.is_exact});
        if (r.uncertainty != null) try stdout.print("/// uncertainty: {any}\n", .{r.uncertainty.?});
        try stdout.print(
            "pub const {s}: f64 = {d};\n",
            .{
                r.name,
                r.value,
            },
        );
    }
    try stdout.flush();
}
