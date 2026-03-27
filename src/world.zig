const std = @import("std");
const Player = @import("player.zig").Player;

pub const EntityKind = enum {
    window,
    eye,
    diamond,
    chip,
};

pub const Entity = struct {
    kind: EntityKind,
    x: i16,
    y: i16,
    width: i16,
    active: bool,

    pub fn visual(self: *const Entity) []const u8 {
        return switch (self.kind) {
            .window => "[##]",
            .eye => "(o)",
            .diamond => "<>",
            .chip => "$",
        };
    }

    pub fn isObstacle(self: *const Entity) bool {
        return self.kind == .window or self.kind == .eye;
    }

    pub fn widthOf(kind: EntityKind) i16 {
        return switch (kind) {
            .window => 4,
            .eye => 3,
            .diamond => 2,
            .chip => 1,
        };
    }
};

pub const MAX_ENTITIES = 128;

pub const CollisionResult = enum {
    none,
    hit_obstacle,
    collected_diamond,
    collected_chip,
};

pub const World = struct {
    entities: [MAX_ENTITIES]Entity,
    entity_count: usize,
    scroll_accumulator: f32,
    spawn_accumulator: f32,
    speed: f32,
    play_width: i16,
    play_height: i16,
    rng: std.Random.DefaultPrng,
    distance: u32,

    pub fn init(play_width: i16, play_height: i16) World {
        const seed = std.crypto.random.int(u64);
        return .{
            .entities = undefined,
            .entity_count = 0,
            .scroll_accumulator = 0,
            .spawn_accumulator = 0,
            .speed = 6.0,
            .play_width = play_width,
            .play_height = play_height,
            .rng = std.Random.DefaultPrng.init(seed),
            .distance = 0,
        };
    }

    pub fn update(self: *World, delta: f32) void {
        self.speed = 6.0 + @as(f32, @floatFromInt(self.distance)) * 0.003;
        if (self.speed > 25.0) self.speed = 25.0;

        self.scroll_accumulator += self.speed * delta;
        const scroll_lines: i16 = @intFromFloat(self.scroll_accumulator);
        if (scroll_lines > 0) {
            self.scroll_accumulator -= @floatFromInt(scroll_lines);
            self.scrollEntities(scroll_lines);
            self.distance += @intCast(scroll_lines);
        }

        self.spawn_accumulator += self.speed * delta;
        const spawn_interval: f32 = 3.0;
        while (self.spawn_accumulator >= spawn_interval) {
            self.spawn_accumulator -= spawn_interval;
            self.spawnRow();
        }
    }

    fn scrollEntities(self: *World, lines: i16) void {
        var write_idx: usize = 0;
        var read_idx: usize = 0;
        while (read_idx < self.entity_count) : (read_idx += 1) {
            self.entities[read_idx].y -= lines;
            if (self.entities[read_idx].y >= -2 and self.entities[read_idx].active) {
                self.entities[write_idx] = self.entities[read_idx];
                write_idx += 1;
            }
        }
        self.entity_count = write_idx;
    }

    fn spawnRow(self: *World) void {
        const random = self.rng.random();
        const num_entities = random.intRangeAtMost(u8, 1, 3);
        const gap_pos = random.intRangeLessThan(i16, 2, self.play_width - 3);

        var i: u8 = 0;
        while (i < num_entities) : (i += 1) {
            if (self.entity_count >= MAX_ENTITIES) break;

            const is_collectible = random.intRangeLessThan(u8, 0, 100) < 20;
            const kind: EntityKind = if (is_collectible)
                (if (random.boolean()) .diamond else .chip)
            else
                (if (random.boolean()) .window else .eye);

            const w = Entity.widthOf(kind);
            const x = random.intRangeLessThan(i16, 1, self.play_width - w - 1);

            if (@abs(x - gap_pos) < 3) continue;

            self.entities[self.entity_count] = .{
                .kind = kind,
                .x = x,
                .y = self.play_height,
                .width = w,
                .active = true,
            };
            self.entity_count += 1;
        }
    }

    pub fn checkCollision(self: *World, player: *const Player) CollisionResult {
        var idx: usize = 0;
        while (idx < self.entity_count) : (idx += 1) {
            const e = &self.entities[idx];
            if (!e.active) continue;
            if (player.collidesWidth(e.x, e.y, e.width, 1)) {
                if (e.isObstacle()) {
                    return .hit_obstacle;
                } else {
                    e.active = false;
                    return switch (e.kind) {
                        .diamond => .collected_diamond,
                        .chip => .collected_chip,
                        else => .none,
                    };
                }
            }
        }
        return .none;
    }
};
