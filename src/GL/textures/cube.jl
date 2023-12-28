# The six faces of a cube, defined to match the OpenGL cubemap texture faces.
# They are ordered in the same way that OpenGL orders them in memory.
@bp_gl_enum(CubeFaces::GLenum,
    pos_x = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
    neg_x = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
    pos_y = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
    neg_y = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
    pos_z = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
    neg_z = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
)
export CubeFaces, E_CubeFaces


"Defines, for a specific face of a cube-map texture, how it is oriented in 3D space."
struct CubeFaceOrientation
    face::E_CubeFaces

    # The 'min' corner maps the first pixel of the 2D texture face
    #    to its 3D corner in the cube-map (from -1 to +1).
    # The 'max' corner does the same for the last pixel.
    min_corner::Vec{3, Int8}
    max_corner::Vec{3, Int8}

    # The 3D axis for each axis of the texture face.
    # 1=X, 2=Y, 3=Z.
    horz_axis::UInt8
    vert_axis::UInt8
end
export CubeFaceOrientation

"
Converts a UV coordinate on a cubemap face to a 3D cubemap vector.
NOTE: be careful with your UV computation!
If your cubemap faces are 512x512 pixels, then the first pixel should have UV `0.5/512`,
    and the last pixel should have UV `511.5/512`.
"
function get_cube_dir(face::CubeFaceOrientation, uv::v2f)::v3f
    dir3D = convert(v3f, face.min_corner)
    @set! dir3D[face.horz_axis] = lerp(face.min_corner[face.horz_axis],
                                       face.max_corner[face.horz_axis],
                                       uv.x)
    @set! dir3D[face.vert_axis] = lerp(face.min_corner[face.vert_axis],
                                       face.max_corner[face.vert_axis],
                                       uv.y)
    return dir3D
end
export get_cube_dir

"The memory layout for each cubemap face, in order on the GPU"
const CUBEMAP_MEMORY_LAYOUT = let v3i8 = Vec{3, Int8}
    (
        CubeFaceOrientation(CubeFaces.pos_x, v3i8(1, 1, 1),   v3i8(1, -1, -1), 3, 2),
        CubeFaceOrientation(CubeFaces.neg_x, v3i8(-1, 1, -1), v3i8(-1, -1, 1), 3, 2),
        CubeFaceOrientation(CubeFaces.pos_y, v3i8(-1, 1, -1), v3i8(1, 1, 1), 1, 3),
        CubeFaceOrientation(CubeFaces.neg_y, v3i8(-1, -1, 1), v3i8(1, -1, -1), 1, 3),
        CubeFaceOrientation(CubeFaces.pos_z, v3i8(-1, 1, 1),  v3i8(1, -1, 1), 1, 2),
        CubeFaceOrientation(CubeFaces.neg_z, v3i8(1, 1, -1),  v3i8(-1, -1, -1), 1, 2),
    )
end
export CUBEMAP_MEMORY_LAYOUT