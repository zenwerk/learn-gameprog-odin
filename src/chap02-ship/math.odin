package chap02_ship

import "core:math"

// 数学定数
PI :: math.PI
TWO_PI :: PI * 2.0
PI_OVER_2 :: PI / 2.0
INFINITY :: math.INF_F32
NEG_INFINITY :: -math.INF_F32

// Vector2は2D座標を表現（Odinの配列として実装）
Vec2 :: [2]f32

// よく使用されるベクトル定数
VEC2_ZERO :: Vec2{0, 0}
VEC2_UNIT_X :: Vec2{1, 0}
VEC2_UNIT_Y :: Vec2{0, 1}
VEC2_NEG_UNIT_X :: Vec2{-1, 0}
VEC2_NEG_UNIT_Y :: Vec2{0, -1}

// Vector3は3D座標を表現
Vec3 :: [3]f32

// よく使用される3Dベクトル定数
VEC3_ZERO :: Vec3{0, 0, 0}
VEC3_UNIT_X :: Vec3{1, 0, 0}
VEC3_UNIT_Y :: Vec3{0, 1, 0}
VEC3_UNIT_Z :: Vec3{0, 0, 1}
VEC3_NEG_UNIT_X :: Vec3{-1, 0, 0}
VEC3_NEG_UNIT_Y :: Vec3{0, -1, 0}
VEC3_NEG_UNIT_Z :: Vec3{0, 0, -1}
VEC3_INFINITY :: Vec3{INFINITY, INFINITY, INFINITY}
VEC3_NEG_INFINITY :: Vec3{NEG_INFINITY, NEG_INFINITY, NEG_INFINITY}

// Matrix3は3x3行列（2D変換用）
Matrix3 :: matrix[3, 3]f32

// よく使用される行列定数
MATRIX3_IDENTITY :: Matrix3{
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
}

// Matrix4は4x4行列（3D変換用）
Matrix4 :: matrix[4, 4]f32

MATRIX4_IDENTITY :: Matrix4{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
}

// 基本的な数学関数（角度変換）
to_radians :: proc(degrees: f32) -> f32 {
    return degrees * PI / 180.0
}

to_degrees :: proc(radians: f32) -> f32 {
    return radians * 180.0 / PI
}

// ゼロに近いかどうかをチェック
near_zero :: proc(val: f32, epsilon: f32 = 0.001) -> bool {
    return abs(val) <= epsilon
}

// 線形補間（2つの値の間を滑らかに補間）
lerp :: proc(a, b, f: f32) -> f32 {
    return a + f * (b - a)
}

// Vector2のヘルパー関数
vec2_length_sq :: proc(v: Vec2) -> f32 {
    // ベクトルの長さの二乗を計算（平方根計算を避けるため）
    return v.x * v.x + v.y * v.y
}

vec2_length :: proc(v: Vec2) -> f32 {
    // ベクトルの長さを計算
    return math.sqrt(vec2_length_sq(v))
}

vec2_normalize :: proc(v: Vec2) -> Vec2 {
    // ベクトルを正規化（長さを1にする）
    length := vec2_length(v)
    if length == 0 {
        return v
    }
    return v / length
}

vec2_dot :: proc(a, b: Vec2) -> f32 {
    // 内積を計算（2つのベクトルの相関性を示す）
    return a.x * b.x + a.y * b.y
}

vec2_lerp :: proc(a, b: Vec2, f: f32) -> Vec2 {
    // 2つのベクトル間を線形補間
    return a + f * (b - a)
}

vec2_reflect :: proc(v, n: Vec2) -> Vec2 {
    // ベクトルvを法線nに対して反射
    return v - 2.0 * vec2_dot(v, n) * n
}

// Vector3のヘルパー関数
vec3_length_sq :: proc(v: Vec3) -> f32 {
    return v.x * v.x + v.y * v.y + v.z * v.z
}

vec3_length :: proc(v: Vec3) -> f32 {
    return math.sqrt(vec3_length_sq(v))
}

vec3_normalize :: proc(v: Vec3) -> Vec3 {
    length := vec3_length(v)
    if length == 0 {
        return v
    }
    return v / length
}

vec3_dot :: proc(a, b: Vec3) -> f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3_cross :: proc(a, b: Vec3) -> Vec3 {
    // 外積を計算（2つのベクトルに垂直なベクトルを求める）
    return Vec3{
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
    }
}

vec3_lerp :: proc(a, b: Vec3, f: f32) -> Vec3 {
    return a + f * (b - a)
}

vec3_reflect :: proc(v, n: Vec3) -> Vec3 {
    return v - 2.0 * vec3_dot(v, n) * n
}

// Matrix3のヘルパー関数
matrix3_create_scale :: proc(x_scale, y_scale: f32) -> Matrix3 {
    // スケール変換行列を作成
    return Matrix3{
        x_scale, 0,       0,
        0,       y_scale, 0,
        0,       0,       1,
    }
}

matrix3_create_uniform_scale :: proc(scale: f32) -> Matrix3 {
    return matrix3_create_scale(scale, scale)
}

matrix3_create_rotation :: proc(theta: f32) -> Matrix3 {
    // Z軸周りの回転行列を作成（2D回転）
    cos_theta := math.cos(theta)
    sin_theta := math.sin(theta)
    return Matrix3{
        cos_theta,  sin_theta, 0,
        -sin_theta, cos_theta, 0,
        0,          0,         1,
    }
}

matrix3_create_translation :: proc(trans: Vec2) -> Matrix3 {
    // 平行移動行列を作成
    return Matrix3{
        1, 0, 0,
        0, 1, 0,
        trans.x, trans.y, 1,
    }
}

// カラー定数（RGB値として定義）
Color :: struct {
    r, g, b: f32,
}

COLOR_BLACK :: Color{0.0, 0.0, 0.0}
COLOR_WHITE :: Color{1.0, 1.0, 1.0}
COLOR_RED :: Color{1.0, 0.0, 0.0}
COLOR_GREEN :: Color{0.0, 1.0, 0.0}
COLOR_BLUE :: Color{0.0, 0.0, 1.0}
COLOR_YELLOW :: Color{1.0, 1.0, 0.0}
COLOR_LIGHT_YELLOW :: Color{1.0, 1.0, 0.88}
COLOR_LIGHT_BLUE :: Color{0.68, 0.85, 0.9}
COLOR_LIGHT_PINK :: Color{1.0, 0.71, 0.76}
COLOR_LIGHT_GREEN :: Color{0.56, 0.93, 0.56}