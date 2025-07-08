package chap02_ship

// Actorの状態を表すenum
Actor_State :: enum {
    Active,  // アクティブ（通常動作中）
    Paused,  // 一時停止中
    Dead,    // 削除対象
}

// Componentはアクターに機能を追加するモジュール
Component :: struct {
    owner:        ^Actor,  // このコンポーネントを所有するアクター
    update_order: int,     // 更新順序（小さいほど先に実行）
}

// Actor（ゲーム内のオブジェクト）を表現する構造体
Actor :: struct {
    // アクターの状態
    state: Actor_State,
    
    // トランスフォーム（位置、回転、スケール）
    position: Vec2,  // ワールド座標での位置
    scale:    f32,   // 拡大縮小率
    rotation: f32,   // 回転角度（ラジアン）
    
    // コンポーネントシステム
    components: [dynamic]^Component,  // アタッチされたコンポーネント群
    
    // ゲームシステムへの参照
    game: ^Game,  // ゲームインスタンスへのポインタ
}

// アクターの初期化
actor_create :: proc(game: ^Game) -> ^Actor {
    actor := new(Actor)
    actor.game = game
    actor.state = .Active
    actor.position = VEC2_ZERO
    actor.scale = 1.0
    actor.rotation = 0.0
    actor.components = make([dynamic]^Component)
    
    // ゲームにアクターを追加
    if game != nil {
        game_add_actor(game, actor)
    }
    
    return actor
}

// アクターの削除
actor_destroy :: proc(actor: ^Actor) {
    // アクターをゲームから削除
    game_remove_actor(actor.game, actor)
    
    // 全コンポーネントを削除
    for component in actor.components {
        component_destroy(component)
    }
    delete(actor.components)
    
    free(actor)
}

// アクターの更新処理（フレーム毎に呼ばれる）
actor_update :: proc(actor: ^Actor, delta_time: f32) {
    if actor.state == .Active {
        // 全コンポーネントを更新
        component_update_components(actor, delta_time)
        
        // アクター固有の更新処理
        actor_update_actor(actor, delta_time)
    }
}

// アクター固有の更新処理（サブクラスでオーバーライド）
actor_update_actor :: proc(actor: ^Actor, delta_time: f32) {
    // デフォルト実装では何もしない
    // 各アクタータイプで具体的な動作を実装
}

// コンポーネントの更新処理
component_update_components :: proc(actor: ^Actor, delta_time: f32) {
    // コンポーネントを更新順序でソート
    // TODO: 毎フレームソートするのは非効率なので、コンポーネント追加時にソートするように改善可能
    for component in actor.components {
        component_update(component, delta_time)
    }
}

// アクターにコンポーネントを追加
actor_add_component :: proc(actor: ^Actor, component: ^Component) {
    // コンポーネントの所有者を設定
    component.owner = actor
    
    // 更新順序に基づいて適切な位置に挿入
    // 簡単な実装：末尾に追加（実際のゲームではソートされた位置に挿入）
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

// コンポーネントの基本機能
component_create :: proc(owner: ^Actor, update_order: int = 100) -> ^Component {
    component := new(Component)
    component.owner = owner
    component.update_order = update_order
    
    // アクターにコンポーネントを追加
    actor_add_component(owner, component)
    
    return component
}

component_destroy :: proc(component: ^Component) {
    // アクターからコンポーネントを削除
    if component.owner != nil {
        actor_remove_component(component.owner, component)
    }
    free(component)
}

// コンポーネントの更新処理（サブクラスでオーバーライド）
component_update :: proc(component: ^Component, delta_time: f32) {
    // デフォルトでは何もしない
}

// ゲッター・セッター関数群
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

actor_get_game :: proc(actor: ^Actor) -> ^Game {
    return actor.game
}