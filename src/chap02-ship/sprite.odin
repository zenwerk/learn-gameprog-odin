package chap02_ship

import sdl "vendor:sdl2"

// スプライトコンポーネントの種類
Sprite_Component_Type :: enum {
    Normal,
    Background,
    Animated,
}

// 背景テクスチャとそのオフセット情報
BG_Texture :: struct {
    texture: ^sdl.Texture,
    offset:  Vec2,
}

// スプライトコンポーネント（画像描画機能を提供）
Sprite_Component :: struct {
    using base: Component,  // Componentを継承
    
    // 描画関連
    texture:    ^sdl.Texture,  // 描画するテクスチャ
    draw_order: int,           // 描画順序（小さいほど背景に描画）
    tex_width:  int,           // テクスチャの幅
    tex_height: int,           // テクスチャの高さ
    type:       Sprite_Component_Type, // スプライトコンポーネントの種類
    
    // 背景専用データ（type == .Backgroundの場合のみ使用）
    bg_textures:  [dynamic]BG_Texture, // 背景テクスチャとオフセットのペア
    screen_size:  Vec2,                // 画面サイズ
    scroll_speed: f32,                 // スクロール速度
}

// スプライトコンポーネントの作成
sprite_component_create :: proc(owner: ^Actor, draw_order: int = 100, type: Sprite_Component_Type = .Normal) -> ^Sprite_Component {
    sprite := new(Sprite_Component)
    sprite.base = Component{owner = owner, update_order = 100}
    sprite.draw_order = draw_order
    sprite.texture = nil
    sprite.tex_width = 0
    sprite.tex_height = 0
    sprite.type = type
    
    // 背景の場合は追加データを初期化
    if type == .Background {
        sprite.bg_textures = make([dynamic]BG_Texture)
        sprite.screen_size = Vec2{1024, 768}
        sprite.scroll_speed = 0.0
    }
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, &sprite.base)
    
    // ゲームの描画リストに追加
    if owner.game != nil {
        game_add_sprite(owner.game, sprite)
    }
    
    return sprite
}

// スプライトコンポーネントの削除
sprite_component_destroy :: proc(sprite: ^Sprite_Component) {
    // ゲームの描画リストから削除
    game_remove_sprite(sprite.owner.game, sprite)
    
    // 背景データのクリーンアップ
    if sprite.type == .Background {
        delete(sprite.bg_textures)
    }
    
    // ベースコンポーネントを削除
    component_destroy(&sprite.base)
    
    free(sprite)
}

// スプライトの描画処理
sprite_component_draw :: proc(sprite: ^Sprite_Component, renderer: ^sdl.Renderer) {
    if sprite.owner == nil {
        return
    }
    
    // テクスチャがない場合は白い矩形を描画
    if sprite.texture == nil {
        actor := sprite.owner
        w := f32(32) * actor.scale  // デフォルトサイズ
        h := f32(32) * actor.scale
        
        // 描画先の矩形を計算
        dest_rect := sdl.FRect{
            x = actor.position.x - w / 2.0,
            y = actor.position.y - h / 2.0,
            w = w,
            h = h,
        }
        
        // 白色で矩形を描画
        sdl.SetRenderDrawColor(renderer, 255, 255, 255, 255)
        sdl.RenderFillRectF(renderer, &dest_rect)
        return
    }
    
    actor := sprite.owner
    
    // アクターの位置、スケール、回転を考慮した描画
    // テクスチャのサイズをアクターのスケールで調整
    w := f32(sprite.tex_width) * actor.scale
    h := f32(sprite.tex_height) * actor.scale
    
    // 描画先の矩形を計算（中心を基準にする）
    dest_rect := sdl.FRect{
        x = actor.position.x - w / 2.0,
        y = actor.position.y - h / 2.0,
        w = w,
        h = h,
    }
    
    
    // 回転角度を度数に変換（SDLは度数を使用）
    angle_degrees := to_degrees(actor.rotation)
    
    // テクスチャの色変調をリセット（白色＝変調なし）
    sdl.SetTextureColorMod(sprite.texture, 255, 255, 255)
    sdl.SetTextureAlphaMod(sprite.texture, 255)
    
    // SDL2のRenderCopyExFを使用（FloatRect対応）
    result := sdl.RenderCopyExF(
        renderer,
        sprite.texture,
        nil,  // ソース矩形（全体を使用）
        &dest_rect,
        f64(angle_degrees),  // SDL2のRenderCopyExFはf64を要求
        nil,  // 中心点をnilにして、dest_rectの中心を使用
        .NONE,  // フリップなし
    )
    
    if result != 0 {
        sdl.Log("RenderCopyExF failed: %s", sdl.GetError())
    }
}

// テクスチャを設定
sprite_component_set_texture :: proc(sprite: ^Sprite_Component, texture: ^sdl.Texture) {
    sprite.texture = texture
    
    // テクスチャのサイズを取得
    if texture != nil {
        w, h: i32
        sdl.QueryTexture(texture, nil, nil, &w, &h)
        sprite.tex_width = int(w)
        sprite.tex_height = int(h)
    }
}

// アニメーションスプライトコンポーネント（複数の画像でアニメーション）
Anim_Sprite_Component :: struct {
    using sprite: Sprite_Component,  // スプライトコンポーネントを継承
    
    // アニメーション関連
    anim_textures: [dynamic]^sdl.Texture,  // アニメーション用テクスチャ配列
    curr_frame:    f32,                     // 現在のフレーム（浮動小数点で滑らかなアニメーション）
    anim_fps:      f32,                     // アニメーションのフレームレート
}

// アニメーションスプライトコンポーネントの作成
anim_sprite_component_create :: proc(owner: ^Actor, draw_order: int = 100) -> ^Anim_Sprite_Component {
    anim_sprite := new(Anim_Sprite_Component)
    anim_sprite.sprite = sprite_component_create(owner, draw_order)^
    anim_sprite.anim_textures = make([dynamic]^sdl.Texture)
    anim_sprite.curr_frame = 0.0
    anim_sprite.anim_fps = 24.0  // デフォルト24FPS
    
    return anim_sprite
}

// アニメーションスプライトコンポーネントの削除
anim_sprite_component_destroy :: proc(anim_sprite: ^Anim_Sprite_Component) {
    delete(anim_sprite.anim_textures)
    sprite_component_destroy(&anim_sprite.sprite)
    free(anim_sprite)
}

// アニメーションの更新処理
anim_sprite_component_update :: proc(anim_sprite: ^Anim_Sprite_Component, delta_time: f32) {
    if len(anim_sprite.anim_textures) > 0 {
        // フレームを進める
        anim_sprite.curr_frame += anim_sprite.anim_fps * delta_time
        
        // フレームが最後まで行ったらループ
        frame_count := f32(len(anim_sprite.anim_textures))
        for anim_sprite.curr_frame >= frame_count {
            anim_sprite.curr_frame -= frame_count
        }
        
        // 現在のフレームのテクスチャを設定
        frame_index := int(anim_sprite.curr_frame)
        if frame_index < len(anim_sprite.anim_textures) {
            sprite_component_set_texture(&anim_sprite.sprite, anim_sprite.anim_textures[frame_index])
        }
    }
}

// アニメーション用テクスチャを設定
anim_sprite_component_set_anim_textures :: proc(anim_sprite: ^Anim_Sprite_Component, textures: []^sdl.Texture) {
    clear(&anim_sprite.anim_textures)
    for texture in textures {
        append(&anim_sprite.anim_textures, texture)
    }
    
    // 最初のフレームを表示
    if len(textures) > 0 {
        sprite_component_set_texture(&anim_sprite.sprite, textures[0])
    }
}

// 背景の更新処理（スクロール）
sprite_component_update_background :: proc(sprite: ^Sprite_Component, delta_time: f32) {
    if sprite.type != .Background do return
    
    // 全ての背景テクスチャのオフセットを更新
    for &bg_tex in sprite.bg_textures {
        if bg_tex.texture == nil do continue
        
        // テクスチャサイズを取得
        w, h: i32
        sdl.QueryTexture(bg_tex.texture, nil, nil, &w, &h)
        texture_width := f32(w)
        
        // 前のオフセット値を保存
        old_offset := bg_tex.offset.x
        
        // オフセットを更新
        bg_tex.offset.x += sprite.scroll_speed * delta_time
        
        // 負の方向（左）にスクロールする場合の無限ループ
        if sprite.scroll_speed < 0.0 {
            // テクスチャが完全に左に移動したら右端にリセット
            if bg_tex.offset.x <= -texture_width {
                bg_tex.offset.x += texture_width
            }
        } else {
            // 正の方向（右）にスクロールする場合の無限ループ
            if bg_tex.offset.x >= texture_width {
                bg_tex.offset.x -= texture_width
            }
        }
    }
}

// 背景の描画処理
sprite_component_draw_background :: proc(sprite: ^Sprite_Component, renderer: ^sdl.Renderer) {
    if sprite.type != .Background do return
    
    // 各背景テクスチャを描画
    for bg_tex in sprite.bg_textures {
        if bg_tex.texture == nil {
            continue
        }
        
        // テクスチャサイズを取得
        w, h: i32
        sdl.QueryTexture(bg_tex.texture, nil, nil, &w, &h)
        texture_width := f32(w)
        texture_height := f32(h)
        
        // 画面を完全に埋めるために必要な描画回数を計算
        // 画面幅に対してテクスチャ幅で何回描画が必要か
        num_tiles := int(sprite.screen_size.x / texture_width) + 2  // +2で余裕を持たせる
        
        // 開始位置を計算（オフセットから左端まで）
        start_x := bg_tex.offset.x
        for start_x > 0 {
            start_x -= texture_width
        }
        
        // 必要な回数だけタイル状に描画
        for i := 0; i < num_tiles; i += 1 {
            x_pos := start_x + f32(i) * texture_width
            
            // 画面外の描画はスキップ（最適化）
            if x_pos + texture_width < 0 || x_pos > sprite.screen_size.x {
                continue
            }
            
            dest_rect := sdl.FRect{
                x = x_pos,
                y = bg_tex.offset.y,
                w = texture_width,
                h = texture_height,
            }
            
            sdl.RenderCopyF(renderer, bg_tex.texture, nil, &dest_rect)
        }
    }
}

// 背景用テクスチャを設定
sprite_component_set_bg_textures :: proc(sprite: ^Sprite_Component, textures: []^sdl.Texture) {
    if sprite.type != .Background do return
    
    clear(&sprite.bg_textures)
    
    for texture, i in textures {
        // 複数のテクスチャを横に並べて配置
        w, h: i32
        sdl.QueryTexture(texture, nil, nil, &w, &h)
        texture_width := f32(w)
        
        bg_tex := BG_Texture{
            texture = texture,
            offset = Vec2{f32(i) * texture_width, 0.0}, // 各テクスチャを横に並べる
        }
        append(&sprite.bg_textures, bg_tex)
    }
}

// 画面サイズを設定
sprite_component_set_screen_size :: proc(sprite: ^Sprite_Component, size: Vec2) {
    if sprite.type != .Background do return
    sprite.screen_size = size
}

// スクロール速度を設定
sprite_component_set_scroll_speed :: proc(sprite: ^Sprite_Component, speed: f32) {
    if sprite.type != .Background do return
    sprite.scroll_speed = speed
}