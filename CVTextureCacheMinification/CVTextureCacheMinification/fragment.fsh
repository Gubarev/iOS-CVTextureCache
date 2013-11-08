precision highp float;

varying vec2      texCoords;
uniform sampler2D uniformTexture0;

void main() {
    vec4 px = texture2D(uniformTexture0, texCoords);
    gl_FragColor = px;
}