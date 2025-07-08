# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Odin game programming learning project. The codebase appears to be in its early stages, with reference C++ game programming examples stored in `.zenwerk/cpp/` that may serve as implementation guides.

## Development Commands

### Building and Running
```bash
# Build the project
odin build src/main.odin -out:bin/game

# Build with optimizations
odin build src/main.odin -out:bin/game -opt:3

# Run directly
odin run src/main.odin

# Debug build
odin build src/main.odin -out:bin/game -debug
```

## Migration Policy from C/C++ to Odin

### Odin is a data-oriented programming language.
- Do not attempt to migrate and reproduce object-oriented structures such as C++ classes and class methods as-is.
- Migrate classes as structures that hold data.
- Implement class methods as a group of functions that operate on structures.
- Name functions by prefixing them with the name of the structure they operate on.
  - Example: A function `bar` that manipulates the structure `Foo` should be named `foo_bar :: proc(..)`.

### Porting code that uses pointers
- When porting functionality that uses pointers from the original C or C++ code, use Odin's regular pointers.
  - Avoid using Odin's multi-pointers (`[^]foo`) whenever possible.
  - Use multi-pointers only when absolutely necessary.
- When C or C++ uses pointers to access elements of dynamic arrays, use Odin's dynamic arrays (`[dynamic]Foo`) for porting.
  - Do not implement arrays using pointer arithmetic on multi-pointers.

### Use Odin's array programming features.
- Implement data representing vectors of up to 4 elements as fixed array type aliases.
  - Example: `Vec2 :: [2]float`
- Odin supports matrix operations for arrays of up to 4 elements. Do not define functions for matrix operations.
- Odin supports the same swizzling syntax as GLSL for fixed arrays of up to 4 elements. Use as appropriate.

### Use Odin's vendor packages
- Port using `vendor:sdl2` for `SDL`
- Use `vendor:sdl3` when the original uses `SDL3`
- For SDL2 documentation, refer to https://pkg.odin-lang.org/vendor/sdl2/
- For SDL3 documentation, refer to https://pkg.odin-lang.org/vendor/sdl3/

### Naming convention
- Import Name -> `snake_case` (but prefer single word)
- Types -> `Ada_Case`
- Enum Values -> `Ada_Case`
- Procedures -> `snake_case`
- Local Variables -> `snake_case`
- Constant Variables -> `SCREAMING_SNAKE_CASE`
- test function name -> `test_foo :: proc(...)` (add prefix `test_`)

### Testing
```bash
# Run tests (when test files exist)
odin test src/
```

## Architecture and Structure

### Directory Layout
- `src/chap*` - Source code files (.odin)
- `bin/` - Compiled binaries (gitignored except .gitkeep)
- `.zenwerk/cpp/` - C++ reference implementations with SDL2, FMOD, and OpenGL examples

## Common Development Tasks

When implementing game features:
1. Reference the C++ examples in `.zenwerk/cpp/` for design patterns
2. Use Odin's core libraries where possible before adding external dependencies
3. Follow Odin naming conventions: snake_case for procedures and variables, PascalCase for types

## Future Considerations

As the project grows, consider:
- Adding Odin bindings for SDL2 or Raylib for graphics
- Implementing audio with Odin bindings for FMOD or miniaudio
- Creating a build script for complex build configurations
- Setting up proper test files with `_test.odin` suffix

## Development Note
- Think in English, then output in Japanese.