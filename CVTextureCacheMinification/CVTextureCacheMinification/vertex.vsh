#extension GL_EXT_separate_shader_objects : enable
precision highp float;

layout(location = 0) attribute vec4 vPosition;
layout(location = 1) attribute vec2 vTexture;

varying vec2 texCoords;



void main() {
    gl_Position = vPosition;
    texCoords   = vTexture;
}