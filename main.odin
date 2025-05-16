package main

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
		{partition_dest.width / 2, partition_dest.height / 2},
		0,
		rl.WHITE,
	)
}

PixelWindowHeight :: 180

main :: proc() {
	rl.InitWindow(1280, 720, "Odin Raylib")
	rl.SetTargetFPS(500)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	player_pos := rl.Vector2{640, 320}
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

	player_flip: bool

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		defer rl.EndMode2D()

		rl.ClearBackground({110, 184, 168, 255})


		if rl.IsKeyDown(.LEFT) {
			player_velocity.x = -400
			player_flip = true
			if current_animation.name != .Run {
				current_animation = player_run
			}
		} else if rl.IsKeyDown(.RIGHT) {
			player_velocity.x = 400
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

		player_velocity.y += 2000 * rl.GetFrameTime()

		if rl.IsKeyPressed(.SPACE) && player_grounded {
			player_velocity.y = -600
		}

		player_pos += player_velocity * rl.GetFrameTime()

		if player_pos.y >= f32(rl.GetScreenHeight()) - f32(current_animation.texture.height) * 4 {
			player_pos.y = f32(rl.GetScreenHeight()) - f32(current_animation.texture.height) * 4
			player_grounded = true
		} else {
			player_grounded = false
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
	}
	rl.CloseWindow()
}
