package chap03_asteroid

// アクターの状態を表すenum
// ゲームオブジェクトのライフサイクルを管理
Actor_State :: enum {
    Active,  // アクティブ状態：通常の更新・描画を行う
    Paused,  // 一時停止状態：更新は行わないが描画は行う
    Dead,    // 削除対象：次のフレームで削除される
}

// アクターの種類を表すenum
// 各アクタータイプ固有の処理を実行するために使用
Actor_Type :: enum {
    Default,   // デフォルト（特別な処理なし）
    Ship,      // プレイヤーの宇宙船
    Asteroid,  // 小惑星
    Laser,     // レーザー弾
}

// コンポーネントの種類を表すenum
// アクターに付加する機能を識別するために使用
Component_Type :: enum {
    Sprite,      // スプライト描画機能
    Move,        // 移動機能
    Input,       // 入力処理機能
    Circle,      // 円形衝突判定機能
}

// コンポーネントの基本構造体
// アクターに機能を追加するモジュラーシステム
Component :: struct {
    owner:        ^Actor,         // このコンポーネントを所有するアクター
    type:         Component_Type, // コンポーネントの種類
    update_order: int,            // 更新順序（小さいほど先に実行される）
}

// ゲーム内のすべてのオブジェクトの基本となるアクター構造体
// 位置・回転・スケールなどの基本的な変換情報と、
// 機能を提供するコンポーネントのリストを持つ
Actor :: struct {
    // アクターの基本状態
    state: Actor_State,  // 現在の状態（アクティブ、一時停止、削除対象）
    type:  Actor_Type,   // アクターの種類（船、小惑星、レーザーなど）
    
    // トランスフォーム（3D数学の概念をゲームに応用）
    position: Vec2,  // ワールド座標での位置
    scale:    f32,   // 拡大縮小率（1.0が標準サイズ）
    rotation: f32,   // 回転角度（ラジアン、0で右向き）
    
    // コンポーネントシステム
    // アクターは「入れ物」で、実際の機能はコンポーネントが提供
    // 例：SpriteComponent（描画）+ MoveComponent（移動）= 動く画像
    components: [dynamic]^Component,
    
    // ゲームシステムへの参照
    game: ^Game,  // ゲーム全体の状態にアクセスするためのポインタ
}

// アクターの作成
// 新しいゲームオブジェクトを生成し、ゲームに登録する
actor_create :: proc(game: ^Game, type: Actor_Type = .Default) -> ^Actor {
    // メモリ上に新しいアクターを確保
    actor := new(Actor)
    
    // 基本設定の初期化
    actor.game = game
    actor.state = .Active  // 作成時はアクティブ状態
    actor.type = type
    actor.position = VEC2_ZERO  // 原点に配置
    actor.scale = 1.0           // 標準サイズ
    actor.rotation = 0.0        // 右向き（0ラジアン）
    actor.components = make([dynamic]^Component)
    
    // ゲームのアクターリストに追加
    // ゲームループ中の追加は安全な方法で行う
    if game != nil {
        game_add_actor(game, actor)
    }
    
    return actor
}

// アクターの削除
// アクターとそのすべてのコンポーネントを破棄する
actor_destroy :: proc(actor: ^Actor) {
    // タイプ固有のクリーンアップ処理
    #partial switch actor.type {
    case .Ship:
        // 宇宙船データをマップから削除
        delete_key(&ship_data_map, actor)
    case .Laser:
        // レーザーデータをマップから削除
        delete_key(&laser_data_map, actor)
    }
    
    // 所有するすべてのコンポーネントを削除
    for component in actor.components {
        component_destroy(component)
    }
    delete(actor.components)
    
    // アクター自体のメモリを解放
    free(actor)
}

// アクターの更新処理（毎フレーム呼び出される）
// アクターの状態に応じて、コンポーネントの更新と専用処理を実行
actor_update :: proc(actor: ^Actor, delta_time: f32) {
    if actor.state == .Active {
        // すべてのコンポーネントを更新順序に従って更新
        component_update_all(actor, delta_time)
        
        // アクタータイプ固有の更新処理を実行
        actor_update_specific(actor, delta_time)
    }
}

// アクタータイプ固有の更新処理
// データ指向プログラミング：継承の代わりにタイプ別関数を使用
actor_update_specific :: proc(actor: ^Actor, delta_time: f32) {
    switch actor.type {
    case .Ship:
        ship_update_actor(actor, delta_time)
    case .Asteroid:
        asteroid_update_actor(actor, delta_time)
    case .Laser:
        laser_update_actor(actor, delta_time)
    case .Default:
        // デフォルトアクターは特別な処理なし
    }
}

// コンポーネントの更新処理
// アクターに付加されたすべてのコンポーネントを更新順序に従って更新
component_update_all :: proc(actor: ^Actor, delta_time: f32) {
    // 注意：実際のゲームでは更新順序でソートが必要
    // ここでは簡易実装として順次実行
    for component in actor.components {
        component_update(component, delta_time)
    }
}

// アクターにコンポーネントを追加
// モジュラー設計：必要な機能を後から追加できる
actor_add_component :: proc(actor: ^Actor, component: ^Component) {
    // コンポーネントの所有者を設定
    component.owner = actor
    
    // アクターのコンポーネントリストに追加
    append(&actor.components, component)
}

// アクターからコンポーネントを削除
actor_remove_component :: proc(actor: ^Actor, component: ^Component) {
    for comp, i in actor.components {
        if comp == component {
            ordered_remove(&actor.components, i)
            break
        }
    }
}

// コンポーネントの作成
component_create :: proc(owner: ^Actor, type: Component_Type, update_order: int = 100) -> ^Component {
    component := new(Component)
    component.owner = owner
    component.type = type
    component.update_order = update_order
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, component)
    
    return component
}

// コンポーネントの削除
component_destroy :: proc(component: ^Component) {
    // アクターからコンポーネントを削除
    if component.owner != nil {
        actor_remove_component(component.owner, component)
    }
    free(component)
}

// コンポーネント固有の更新処理
// タイプ別に異なる処理を実行
component_update :: proc(component: ^Component, delta_time: f32) {
    switch component.type {
    case .Sprite:
        sprite_component_update(component, delta_time)
    case .Move:
        move_component_update(component, delta_time)
    case .Input:
        input_component_update(component, delta_time)
    case .Circle:
        circle_component_update(component, delta_time)
    }
}

// ゲッター・セッター関数群
// アクターの基本プロパティへの安全なアクセスを提供

actor_get_position :: proc(actor: ^Actor) -> Vec2 {
    return actor.position
}

actor_set_position :: proc(actor: ^Actor, pos: Vec2) {
    actor.position = pos
}

actor_get_scale :: proc(actor: ^Actor) -> f32 {
    return actor.scale
}

actor_set_scale :: proc(actor: ^Actor, scale: f32) {
    actor.scale = scale
}

actor_get_rotation :: proc(actor: ^Actor) -> f32 {
    return actor.rotation
}

actor_set_rotation :: proc(actor: ^Actor, rotation: f32) {
    actor.rotation = rotation
}

actor_get_state :: proc(actor: ^Actor) -> Actor_State {
    return actor.state
}

actor_set_state :: proc(actor: ^Actor, state: Actor_State) {
    actor.state = state
}

// アクターの前進方向ベクトルを取得
// 現在の回転角度から前進方向を計算（移動処理で使用）
actor_get_forward :: proc(actor: ^Actor) -> Vec2 {
    return angle_to_vector(actor.rotation)
}