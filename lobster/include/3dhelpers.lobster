// helper functions typical for 3d games

// implement a standard FPS view with xy as the ground plane, and Z up
// first call update, then view

include "vec.lobster"
include "color.lobster"
include "texture.lobster"

camera_position := xyz_0
camera_yaw := 0.0
camera_pitch := 0.0
camera_velocity := xyz_0

def camera_FPS_update(upkey, leftkey, downkey, rightkey, movementspeed:float, mousesens:float, dopitch):
    camera_yaw -= gl_mousedelta(0).x / mousesens
    if dopitch:
        camera_pitch -= gl_mousedelta(0).y / mousesens
        camera_pitch = min(85.0, max(-85.0, camera_pitch))

    move   := (gl_button(upkey) >= 1) - (gl_button(downkey) >= 1)
    strafe := (gl_button(rightkey) >= 1) - (gl_button(leftkey) >= 1)
    friction :== 20
    velspeed := min(1.0, friction * gl_deltatime())
    dir := vecfromyawpitch(camera_yaw, camera_pitch, move, strafe)
    camera_velocity = lerp(camera_velocity, dir, velspeed)
    camera_position += camera_velocity * gl_deltatime() * movementspeed

def camera_set_z_up_worldspace(f):
    // Default OpenGL view looks along -Z (Y up). We want a worldspace where -Z is down:
    gl_rotate_x(sincos(-90)): f()

def to_z_up(v):
    // Convert points that are in Y up space to Z up.
    xyz { v.x, -v.z, v.y }

def camera_FPS_view():
    camera_set_z_up_worldspace(): nil
    gl_rotate_x(sincos(-camera_pitch - 90))
    gl_rotate_z(sincos(-camera_yaw))
    gl_translate(-camera_position)

def camera_forward_vector(): vecfromyawpitch(camera_yaw, camera_pitch,      1.0, 0.0)
def camera_up_vector():      vecfromyawpitch(camera_yaw, camera_pitch + 90, 1.0, 0.0)
def camera_left_vector():    vecfromyawpitch(camera_yaw, camera_pitch,      0.0, 1.0)

// an alternative way to set a 3D camera with an overriding direction, call this instead of camera_FPS_update,
// then still call camera_FPS_view as before:

def camera_direction(v):
    v = normalize(v)
    camera_yaw = atan2(v) - 90  // look along Y rather than X
    camera_pitch = arcsin(v.z)

def camera_2d_worldspace(size:xy_f, origin:xy_f, scale:xy_f):
    ws := float(gl_windowsize())
    gl_translate(ws * origin)
    sc := ws / size
    gl_scale(scale * min(sc))

private delta_time_log :== map(60): 1 / 30.0
def gl_deltatime_over_time():
    delta_time_log.push(gl_deltatime())
    delta_time_log.remove(0)
    (delta_time_log.fold(0.0): _a + _e) / delta_time_log.length

// Pass nil for tex to have it created. Recreates tex if the wrong size. Renders f. Returns tex.
// Depth texture automatically created if depth is true and depthtex is nil.
def render_to_texture(tex, size, depth, depthtex, texture_format, f):
    if !tex || !equal(gl_texturesize(tex), size):
        tex = gl_createblanktexture(size, color_black, texture_format)
    assert tex  // FIXME
    assert gl_switchtoframebuffer(tex, depth, texture_format, nil, depthtex)
    f()
    assert gl_switchtoframebuffer(nil)
    tex

def create_depth_texture(tex, size):
    if !tex || !equal(gl_texturesize(tex), size):
        tex = gl_createblanktexture(size, color_black, texture_format_depth |
            texture_format_nomipmap | texture_format_clamp | texture_format_nearest_mag)
    assert tex  // FIXME
    tex

// Same, but processes a source texture. Takes size from that texture.
def render_to_texture_from(tex, shader, srctex):
    texture_format :== texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag
    render_to_texture(tex, gl_texturesize(srctex), false, nil, texture_format):
        gl_setprimitivetexture(0, srctex)
        gl_setshader(shader)
        gl_rect(float(gl_texturesize(srctex)))

// Same but renders to the screen.
def post_process(tex, size, shader, depth, f):
    texture_format :== texture_format_clamp | texture_format_nomipmap
    tex = render_to_texture(tex, size, depth, nil, texture_format, f)
    gl_setprimitivetexture(0, tex, texture_format)
    gl_setshader(shader)
    gl_translate(xy_f { 0, size.y }):
        gl_rect(xy_f { size.x, -size.y })
    tex

