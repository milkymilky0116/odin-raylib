#+feature dynamic-literals

package main

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

AnimationName :: enum {
	Idle,
	Run,
}

Animation :: struct {
	texture:       rl.Texture2D,
	num_frames:    int,
	frame_timer:   f32,
	current_frame: int,
	frame_length:  f32,
	name:          AnimationName,
}

update_animation :: proc(a: ^Animation) {
	a.frame_timer += rl.GetFrameTime()

	if a.frame_timer > a.frame_length {
		a.current_frame += 1
		a.frame_timer = 0
		if a.current_frame == a.num_frames {
			a.current_frame = 0
		}
	}
}

draw_animation :: proc(a: Animation, pos: rl.Vector2, flip: bool) {
	partition := rl.Rectangle {
		x      = f32(a.current_frame) * f32(a.texture.width) / f32(a.num_frames),
		y      = 0,
		width  = f32(a.texture.width) / f32(a.num_frames),
		height = f32(a.texture.height),
	}


	if flip {
		partition.width = -partition.width
	}

	partition_dest := rl.Rectangle {
		x      = pos.x,
		y      = pos.y,
		width  = f32(a.texture.width) / f32(a.num_frames),
		height = f32(a.texture.height),
	}
	rl.DrawTexturePro(
		a.texture,
		partition,
		partition_dest,
		{partition_dest.width / 2, partition_dest.height},
		0,
		rl.WHITE,
	)
}

PixelWindowHeight :: 180

Level :: struct {
	platforms: [dynamic]rl.Vector2,
}

platform_collider :: proc(pos: rl.Vector2) -> rl.Rectangle {
	return {pos.x, pos.y, 96, 16}
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}

		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}

		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(1280, 720, "Odin Raylib")
	rl.SetTargetFPS(500)
	player_pos: rl.Vector2
	player_velocity: rl.Vector2
	player_grounded: bool

	player_run := Animation {
		texture      = rl.LoadTexture("assets/cat_run.png"),
		num_frames   = 4,
		frame_length = 0.1,
		name         = .Run,
	}

	player_idle := Animation {
		texture      = rl.LoadTexture("assets/cat_idle.png"),
		num_frames   = 2,
		frame_length = 0.5,
		name         = .Idle,
	}

	current_animation := player_idle

	level: Level

	if level_data, ok := os.read_entire_file("level.json", context.temp_allocator); ok {
		if err := json.unmarshal(level_data, &level); err != nil {
			append(&level.platforms, rl.Vector2{-20, 20})
			fmt.eprint("error occured while loading map data: %v", err)
		}
	} else {
		append(&level.platforms, rl.Vector2{-20, 20})
		fmt.eprint("error occured while loading map data")
	}
	platform_texture := rl.LoadTexture("assets/platform.png")
	editing := false

	player_flip: bool

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		defer rl.EndMode2D()

		rl.ClearBackground({110, 184, 168, 255})


		if rl.IsKeyDown(.LEFT) {
			player_velocity.x = -100
			player_flip = true
			if current_animation.name != .Run {
				current_animation = player_run
			}
		} else if rl.IsKeyDown(.RIGHT) {
			player_velocity.x = 100
			player_flip = false
			if current_animation.name != .Run {
				current_animation = player_run
			}
		} else {
			player_velocity.x = 0
			if current_animation.name != .Idle {
				current_animation = player_idle
			}
		}

		player_velocity.y += 1000 * rl.GetFrameTime()

		if rl.IsKeyPressed(.SPACE) && player_grounded {
			player_velocity.y = -300
		}

		player_pos += player_velocity * rl.GetFrameTime()

		player_feet_collider := rl.Rectangle{player_pos.x - 4, player_pos.y - 4, 8, 4}

		player_grounded = false

		for platform in level.platforms {
			if rl.CheckCollisionRecs(player_feet_collider, platform_collider(platform)) &&
			   player_velocity.y > 0 {
				player_velocity.y = 0
				player_pos.y = platform.y
				player_grounded = true
			}
		}


		update_animation(&current_animation)

		screen_height := f32(rl.GetScreenHeight())
		camera := rl.Camera2D {
			zoom   = screen_height / PixelWindowHeight,
			offset = {f32(rl.GetScreenWidth() / 2), f32(screen_height / 2)},
			target = player_pos,
		}

		rl.BeginMode2D(camera)
		draw_animation(current_animation, player_pos, player_flip)
		for platform in level.platforms {
			rl.DrawTextureV(platform_texture, platform, rl.WHITE)
		}
		// rl.DrawRectangleRec(player_feet_collider, {0, 255, 0, 100})

		if rl.IsKeyPressed(.F2) {
			editing = !editing
		}

		if editing {
			mouse_point := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
			rl.DrawTextureV(platform_texture, mouse_point, rl.WHITE)

			if rl.IsMouseButtonPressed(.LEFT) {
				append(&level.platforms, mouse_point)
			}

			if rl.IsMouseButtonPressed(.RIGHT) {
				for platform, index in level.platforms {
					if rl.CheckCollisionPointRec(mouse_point, platform_collider(platform)) {
						unordered_remove(&level.platforms, index)
						break
					}
				}
			}
		}
	}

	rl.CloseWindow()

	if level_data, err := json.marshal(level, allocator = context.temp_allocator); err == nil {
		os.write_entire_file("level.json", level_data)
	}

	free_all(context.temp_allocator)
	delete(level.platforms)
}
