package chap03_asteroid

import sdl "vendor:sdl2"

// スプライト描画コンポーネント
// ゲームオブジェクトに画像表示機能を追加
// テクスチャの管理と描画順序の制御を行う
Sprite_Component :: struct {
    using base: Component,  // 基本コンポーネント機能を継承
    
    // 描画関連のデータ
    texture:    ^sdl.Texture,  // 描画するテクスチャ（画像データ）
    draw_order: int,           // 描画順序（小さいほど背景に描画）
    tex_width:  int,           // テクスチャの元の幅
    tex_height: int,           // テクスチャの元の高さ
}

// 移動コンポーネント
// アクターに物理的な移動機能を追加
// 前進速度と角速度を管理し、位置と回転を更新
Move_Component :: struct {
    using base: Component,
    
    // 移動関連のデータ
    forward_speed:  f32,  // 前進速度（ピクセル/秒）
    angular_speed:  f32,  // 角速度（ラジアン/秒）
    mass:          f32,  // 質量（将来の物理演算拡張用）
}

// 入力処理コンポーネント
// プレイヤーのキーボード入力を移動に変換
// Move_Componentを拡張して入力に基づく移動を実現
Input_Component :: struct {
    using move: Move_Component,  // 移動機能を含む
    
    // 入力関連の設定
    max_forward_speed: f32,  // 最大前進速度
    max_angular_speed: f32,  // 最大角速度
    forward_key:       sdl.Scancode,  // 前進キー（SDL scancode）
    back_key:          sdl.Scancode,  // 後退キー
    clockwise_key:     sdl.Scancode,  // 時計回りキー
    counter_clockwise_key: sdl.Scancode,  // 反時計回りキー
}

// 円形衝突判定コンポーネント
// アクターに円形の当たり判定を追加
// シンプルで高速な衝突判定を提供
Circle_Component :: struct {
    using base: Component,
    
    // 衝突判定関連のデータ
    radius: f32,  // 衝突判定円の半径
}

// スプライトコンポーネントの作成
sprite_component_create :: proc(owner: ^Actor, draw_order: int = 100) -> ^Sprite_Component {
    sprite := new(Sprite_Component)
    sprite.base = Component{
        owner = owner,
        type = .Sprite,
        update_order = 100,
    }
    sprite.draw_order = draw_order
    sprite.texture = nil
    sprite.tex_width = 0
    sprite.tex_height = 0
    
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
    
    // メモリ解放
    free(sprite)
}

// スプライトコンポーネントの更新
// 現在は特別な更新処理なし（将来のアニメーション用）
sprite_component_update :: proc(component: ^Component, delta_time: f32) {
    // スプライトの更新処理（現在は何もしない）
}

// スプライトの描画処理
// アクターの位置・回転・スケールを適用してテクスチャを描画
sprite_component_draw :: proc(sprite: ^Sprite_Component, renderer: ^sdl.Renderer) {
    if sprite.owner == nil || sprite.texture == nil {
        return
    }
    
    actor := sprite.owner
    
    // アクターの変換情報を適用した描画サイズを計算
    w := f32(sprite.tex_width) * actor.scale
    h := f32(sprite.tex_height) * actor.scale
    
    // 描画先の矩形を計算（アクターの位置を中心とする）
    dest_rect := sdl.FRect{
        x = actor.position.x - w / 2.0,
        y = actor.position.y - h / 2.0,
        w = w,
        h = h,
    }
    
    // 回転角度を度数に変換（SDLは度数を使用）
    angle_degrees := to_degrees(actor.rotation)
    
    // 回転・拡縮を適用してテクスチャを描画
    sdl.RenderCopyExF(
        renderer,
        sprite.texture,
        nil,  // ソース矩形（全体を使用）
        &dest_rect,
        f64(angle_degrees),
        nil,  // 回転中心（中央を使用）
        .NONE,  // フリップなし
    )
}

// テクスチャを設定
sprite_component_set_texture :: proc(sprite: ^Sprite_Component, texture: ^sdl.Texture) {
    sprite.texture = texture
    
    // テクスチャのサイズを取得して保存
    if texture != nil {
        w, h: i32
        sdl.QueryTexture(texture, nil, nil, &w, &h)
        sprite.tex_width = int(w)
        sprite.tex_height = int(h)
    }
}

// 移動コンポーネントの作成
move_component_create :: proc(owner: ^Actor, update_order: int = 10) -> ^Move_Component {
    move := new(Move_Component)
    move.base = Component{
        owner = owner,
        type = .Move,
        update_order = update_order,
    }
    move.forward_speed = 0.0
    move.angular_speed = 0.0
    move.mass = 1.0
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, &move.base)
    
    return move
}

// 移動コンポーネントの削除
move_component_destroy :: proc(move: ^Move_Component) {
    free(move)
}

// 移動コンポーネントの更新
// 速度に基づいてアクターの位置と回転を更新
move_component_update :: proc(component: ^Component, delta_time: f32) {
    // コンポーネントを移動コンポーネントとしてキャスト
    move := cast(^Move_Component)component
    
    if move == nil || move.owner == nil {
        return
    }
    
    actor := move.owner
    
    // 角速度に基づいて回転を更新
    if !near_zero(move.angular_speed) {
        actor.rotation += move.angular_speed * delta_time
    }
    
    // 前進速度に基づいて位置を更新
    if !near_zero(move.forward_speed) {
        // アクターの向いている方向のベクトルを計算
        forward := actor_get_forward(actor)
        // 位置を更新
        actor.position += forward * move.forward_speed * delta_time
    }
}

// 入力コンポーネントの作成
input_component_create :: proc(owner: ^Actor, update_order: int = 1) -> ^Input_Component {
    input := new(Input_Component)
    input.move.base = Component{
        owner = owner,
        type = .Input,
        update_order = update_order,
    }
    
    // デフォルト設定
    input.max_forward_speed = 300.0
    input.max_angular_speed = TWO_PI
    input.forward_key = sdl.SCANCODE_W
    input.back_key = sdl.SCANCODE_S
    input.clockwise_key = sdl.SCANCODE_D
    input.counter_clockwise_key = sdl.SCANCODE_A
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, &input.move.base)
    
    return input
}

// 入力コンポーネントの削除
input_component_destroy :: proc(input: ^Input_Component) {
    free(input)
}

// 入力コンポーネントの更新
// キーボード状態を読み取り、移動速度を設定
input_component_update :: proc(component: ^Component, delta_time: f32) {
    input := cast(^Input_Component)component
    
    if input == nil {
        return
    }
    
    // キーボード状態を取得
    state := sdl.GetKeyboardState(nil)
    
    // 前進・後退の処理
    forward_speed: f32 = 0
    if state[input.forward_key] != 0 {
        forward_speed += input.max_forward_speed
    }
    if state[input.back_key] != 0 {
        forward_speed -= input.max_forward_speed
    }
    input.forward_speed = forward_speed
    
    // 回転の処理
    angular_speed: f32 = 0
    if state[input.clockwise_key] != 0 {
        angular_speed += input.max_angular_speed
    }
    if state[input.counter_clockwise_key] != 0 {
        angular_speed -= input.max_angular_speed
    }
    input.angular_speed = angular_speed
    
    // 移動コンポーネントとして更新処理も実行
    // Input_ComponentはMove_Componentを継承しているため
    move_component_update(&input.move.base, delta_time)
}

// 円形衝突判定コンポーネントの作成
circle_component_create :: proc(owner: ^Actor, radius: f32, update_order: int = 50) -> ^Circle_Component {
    circle := new(Circle_Component)
    circle.base = Component{
        owner = owner,
        type = .Circle,
        update_order = update_order,
    }
    circle.radius = radius
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, &circle.base)
    
    return circle
}

// 円形衝突判定コンポーネントの削除
circle_component_destroy :: proc(circle: ^Circle_Component) {
    free(circle)
}

// 円形衝突判定コンポーネントの更新
// 現在は特別な更新処理なし
circle_component_update :: proc(component: ^Component, delta_time: f32) {
    // 円形コンポーネントの更新処理（現在は何もしない）
}

// 2つの円形衝突判定の交差チェック
// 2つの円の中心間距離が半径の合計より小さければ衝突
circle_intersect :: proc(a, b: ^Circle_Component) -> bool {
    if a == nil || b == nil || a.owner == nil || b.owner == nil {
        return false
    }
    
    // 中心間の距離の二乗を計算
    diff := a.owner.position - b.owner.position
    dist_sq := vec2_length_squared(diff)
    
    // 半径の合計の二乗を計算
    radius_sum := a.radius + b.radius
    radius_sum_sq := radius_sum * radius_sum
    
    // 距離の二乗が半径の合計の二乗より小さければ衝突
    return dist_sq <= radius_sum_sq
}