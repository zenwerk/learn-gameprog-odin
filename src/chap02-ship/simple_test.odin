package chap02_ship

import sdl "vendor:sdl2"
import img "vendor:sdl2/image"

// 簡単なテストプログラム
test_main :: proc() {
    // SDL初期化
    if sdl.Init({.VIDEO}) != 0 {
        return
    }
    defer sdl.Quit()
    
    // ウィンドウ作成
    window := sdl.CreateWindow("Test", 100, 100, 800, 600, {})
    if window == nil {
        return
    }
    defer sdl.DestroyWindow(window)
    
    // レンダラー作成
    renderer := sdl.CreateRenderer(window, -1, {.ACCELERATED})
    if renderer == nil {
        return
    }
    defer sdl.DestroyRenderer(renderer)
    
    // 画像初期化
    img.Init({.PNG})
    defer img.Quit()
    
    // 宇宙船テクスチャ読み込み
    surface := img.Load("src/chap02-ship/Assets/Ship01.png")
    if surface == nil {
        sdl.Log("Failed to load ship texture")
        return
    }
    defer sdl.FreeSurface(surface)
    
    texture := sdl.CreateTextureFromSurface(renderer, surface)
    if texture == nil {
        return
    }
    defer sdl.DestroyTexture(texture)
    
    // メインループ
    running := true
    for running {
        event: sdl.Event
        for sdl.PollEvent(&event) {
            if event.type == .QUIT {
                running = false
            }
        }
        
        // 背景を青に
        sdl.SetRenderDrawColor(renderer, 0, 0, 100, 255)
        sdl.RenderClear(renderer)
        
        // 宇宙船を描画
        dest := sdl.Rect{x = 100, y = 300, w = 64, h = 29}
        sdl.RenderCopy(renderer, texture, nil, &dest)
        
        sdl.RenderPresent(renderer)
        
        sdl.Delay(16)
    }
}