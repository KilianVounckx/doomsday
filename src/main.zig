pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = gpa.allocator();

    const level = levelFromArgs(allocator) catch |err| switch (err) {
        error.InvalidLevel => return,
        else => |e| return e,
    };

    var rng = rand.DefaultPrng.init(Time.now().nanosecond);
    const random = rng.random();

    try doomsday(allocator, random, level);
}

pub fn levelFromArgs(allocator: Allocator) !Level {
    var args = try process.argsWithAllocator(allocator);
    defer args.deinit();
    std.debug.assert(args.skip());

    return if (args.next()) |arg|
        if (mem.eql(u8, arg, "easy"))
            Level.easy
        else if (mem.eql(u8, arg, "medium"))
            Level.medium
        else if (mem.eql(u8, arg, "hard"))
            Level.hard
        else {
            try stdout.print(usage, .{});
            return error.InvalidLevel;
        }
    else
        .medium;
}

const usage = "Usage: doomsday [easy | medium | hard (default: medium)]\n";

const Level = enum {
    easy,
    medium,
    hard,
};

fn doomsday(allocator: Allocator, random: Random, level: Level) !void {
    const year = switch (level) {
        .easy => 2000,
        .medium => random.intRangeLessThan(u16, 2000, 2099),
        .hard => random.intRangeLessThan(u16, 1700, 2999),
    };
    const new_year_date = Date{ .year = year };
    const num_days_in_year: i32 = if (datetime.isLeapYear(year)) 366 else 365;

    const day_of_year = random.intRangeLessThan(i32, 0, num_days_in_year);
    const date = new_year_date.shiftDays(day_of_year);

    const day = date.dayOfWeek();

    try stdout.print(
        "What day of week is {d} {s} {d}?\n",
        .{ date.day, @tagName(@intToEnum(datetime.Month, date.month)), date.year },
    );

    const start = Datetime.now();

    while (true) {
        const line = (try stdin.readUntilDelimiterOrEofAlloc(
            allocator,
            '\n',
            math.maxInt(usize),
        )) orelse {
            try stdout.print("The correct answer was: {s}\n", .{@tagName(day)});
            break;
        };
        defer allocator.free(line);
        const guess = meta.stringToEnum(datetime.Weekday, line) orelse {
            try stdout.print("Invalid day (make sure to capitalize)\n", .{});
            continue;
        };

        if (guess == day) {
            const end = Datetime.now();
            const delta = end.sub(start).totalSeconds();
            try stdout.print(
                \\Correct!
                \\You got it in {d} seconds!
                \\
            , .{delta});
            break;
        }
        try stdout.print("Wrong.\n", .{});
    }
}

const day_buffer_len = blk: {
    var max: usize = 0;
    inline for (meta.fields(datetime.Weekday)) |field| {
        if (field.name.len > max) max = field.name.len;
    }
    break :blk max;
};

const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const meta = std.meta;
const mem = std.mem;
const math = std.math;
const process = std.process;
const rand = std.rand;
const Allocator = mem.Allocator;
const Random = rand.Random;

const datetime = @import("datetime").datetime;
const Date = datetime.Date;
const Time = datetime.Time;
const Datetime = datetime.Datetime;
