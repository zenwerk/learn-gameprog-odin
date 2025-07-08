package chap03_asteroid

import "core:math"
import "core:math/rand"

// 数学定数
PI :: math.PI
TWO_PI :: PI * 2.0
PI_OVER_2 :: PI / 2.0

// 2次元ベクトル（Odinの配列機能を活用）
// ゲーム内の位置、速度、方向などを表現するために使用
Vec2 :: [2]f32

// よく使用されるベクトル定数
VEC2_ZERO :: Vec2{0, 0}         // 原点
VEC2_UNIT_X :: Vec2{1, 0}       // 右方向の単位ベクトル
VEC2_UNIT_Y :: Vec2{0, 1}       // 上方向の単位ベクトル
VEC2_NEG_UNIT_X :: Vec2{-1, 0}  // 左方向の単位ベクトル
VEC2_NEG_UNIT_Y :: Vec2{0, -1}  // 下方向の単位ベクトル

// 角度変換ユーティリティ
// 度数からラジアンへの変換（SDLは度数、数学計算はラジアンを使用）
to_radians :: proc(degrees: f32) -> f32 {
    return degrees * PI / 180.0
}

// ラジアンから度数への変換（描画時にSDLに渡す用）
to_degrees :: proc(radians: f32) -> f32 {
    return radians * 180.0 / PI
}

// 浮動小数点数がゼロに近いかをチェック
// 浮動小数点の精度誤差を考慮した比較
near_zero :: proc(val: f32, epsilon: f32 = 0.001) -> bool {
    return abs(val) <= epsilon
}

// 線形補間（リープ）
// 2つの値の間を滑らかに補間する（アニメーション等で使用）
lerp :: proc(a, b, t: f32) -> f32 {
    return a + t * (b - a)
}

// ベクトルの長さの二乗を計算
// 実際の長さが不要で比較のみ行う場合は平方根計算を避けて高速化
vec2_length_squared :: proc(v: Vec2) -> f32 {
    return v.x * v.x + v.y * v.y
}

// ベクトルの長さを計算
// 距離の計算や正規化で使用
vec2_length :: proc(v: Vec2) -> f32 {
    return math.sqrt(vec2_length_squared(v))
}

// ベクトルの正規化（長さを1にする）
// 方向のみが重要で大きさを統一したい場合に使用
vec2_normalize :: proc(v: Vec2) -> Vec2 {
    length := vec2_length(v)
    if near_zero(length) {
        return VEC2_ZERO
    }
    return v / length
}

// 内積の計算
// 2つのベクトルの類似度や投影の計算で使用
vec2_dot :: proc(a, b: Vec2) -> f32 {
    return a.x * b.x + a.y * b.y
}

// 2つのベクトル間の線形補間
vec2_lerp :: proc(a, b: Vec2, t: f32) -> Vec2 {
    return a + t * (b - a)
}

// ベクトルの反射
// 法線に対してベクトルを反射させる（ボールの跳ね返りなど）
vec2_reflect :: proc(v, normal: Vec2) -> Vec2 {
    return v - 2.0 * vec2_dot(v, normal) * normal
}

// 角度からベクトルを作成
// 宇宙船の向きから前進方向ベクトルを計算する際に使用
angle_to_vector :: proc(angle: f32) -> Vec2 {
    return Vec2{math.cos(angle), math.sin(angle)}
}

// ベクトルから角度を計算
vec2_to_angle :: proc(v: Vec2) -> f32 {
    return math.atan2(v.y, v.x)
}

// ランダム数生成ユーティリティ
// 指定範囲内のランダムな浮動小数点数を生成
random_float :: proc(min, max: f32) -> f32 {
    // 注意：実際のゲームではより高品質な乱数生成器を使用することを推奨
    return min + rand.float32() * (max - min)
}

// 指定範囲内のランダムなベクトルを生成
// 小惑星の初期位置や速度の設定で使用
random_vector :: proc(min_x, max_x, min_y, max_y: f32) -> Vec2 {
    return Vec2{
        random_float(min_x, max_x),
        random_float(min_y, max_y),
    }
}

// 円周上のランダムな点を生成
// 小惑星の配置やパーティクル効果で使用
random_unit_vector :: proc() -> Vec2 {
    angle := random_float(0, TWO_PI)
    return angle_to_vector(angle)
}