#=
The depth buffer is used to keep track of how close each rendered pixel is to the camera.
As new pixels are rendered, any that are behind the depth buffer are discarded,
  and any that are in front of the depth buffer will be applied and update the buffer's value.
This default behavior can be configured in a number of ways.

The stencil buffer is a similar kind of filter, but with integer data and bitwise operations
   instead of floating-point depth values.
=#


#=
Comparisons that can be used for depth/stencil testing,
   against the value currently in the depth/stencil buffer.
In depth testing, the "test" value is the incoming fragment's depth.
In stencil testing, the "test" value is a constant you can set, called the "reference".
=#
@bp_gl_enum(ValueTests::GLenum,
    # Always passes ('true').
    pass = GL_ALWAYS,
    # Always fails ('false').
    fail = GL_NEVER,

    # Passes if the "test" value is less than the existing value.
    less_than = GL_LESS,
    # Passes if the "test" value is less than or equal to the existing value.
    less_than_or_equal = GL_LEQUAL,

    # Passes if the "test" value is greater than the existing value.
    greater_than = GL_GREATER,
    # Passes if the "test" value is greater than or equal to the existing value.
    greater_than_or_equal = GL_GEQUAL,

    # Passes if the "test" value is equal to the existing value.
    equal = GL_EQUAL,
    # Passes if the "test" value is not equal to the existing value.
    not_equal = GL_NOTEQUAL
)
export ValueTests, E_ValueTests

#=
The various actions that can be performed on a stencil buffer pixel,
   based on a new fragment that was just drawn over it.
=#
@bp_gl_enum(StencilOps::GLenum,
    # Don't do anything.
    nothing = GL_KEEP,

    # Set the value to 0.
    zero = GL_ZERO,
    # Replace the stencil buffer's value with the "reference" value used for the test.
    replace = GL_REPLACE,
    # Flip all bits in the buffer (a.k.a. bitwise NOT).
    invert = GL_INVERT,

    # Increment the stencil buffer's value, clamping it to stay inside its range.
    increment_clamp = GL_INCR,
    # Increment the stencil buffer's value, wrapping around to 0 if it passes the max value.
    increment_wrap = GL_INCR_WRAP,

    # Decrement the stencil buffer's value, clamping it to stay inside its range.
    decrement_clamp = GL_DECR,
    # Decrement the stencil buffer's value, wrapping around to the max value if it passes below 0.
    decrement_wrap = GL_DECR_WRAP,
)
export StencilOps, E_StencilOps


"
A predicate/filter evaluated for the stencil buffer,
   to control which pixels can be drawn into.
"
struct StencilTest
    test::E_ValueTests
    # The value to be compared against the stencil buffer.
    reference::GLint
    # Limits the bits that are used in the test.
    bitmask::GLuint

    StencilTest(test::E_ValueTests, reference::GLint, mask::GLuint = ~GLuint(0)) = new(test, reference, mask)
    StencilTest() = new(ValueTests.pass, GLint(0), ~GLuint(0))
end
export StencilTest

"What happens to the stencil buffer when a fragment is going through the stencil/depth tests"
struct StencilResult
    on_failed_stencil::E_StencilOps
    on_passed_stencil_failed_depth::E_StencilOps
    on_passed_all::E_StencilOps

    StencilResult(on_failed_stencil, on_passed_stencil_failed_depth, on_passed_all) = new(
        on_failed_stencil, on_passed_stencil_failed_depth, on_passed_all
    )
    StencilResult() = new(StencilOps.nothing, StencilOps.nothing, StencilOps.nothing)
end
export StencilResult