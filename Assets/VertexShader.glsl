/*
Title: Basic Ray Tracer
File Name: VertexShader.glsl
Copyright © 2019
Original authors: Niko Procopi
Written under the supervision of David I. Schwartz, Ph.D., and
supported by a professional development seed grant from the B. Thomas
Golisano College of Computing & Information Sciences
(https://www.rit.edu/gccis) at the Rochester Institute of Technology.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

 // Identifies the version of the shader, this line must be on a separate line from the rest of the shader code
#version 400 core

// The coordinates for the fragment shader to use to determine where the pixel is on the quad.
out vec2 textureCoord;

void main(void)
{
	// 0, 0
	// 1, 0
	// 0, 1
	// 1, 1
	vec2 uv = vec2(gl_VertexID % 2, gl_VertexID / 2);

	// export to fragment shader
	textureCoord = uv;

	// convert [0 to 1] range to [-1 to 1]
	uv *= vec2(2);
	uv -= vec2(1);

	//position
	gl_Position = vec4(uv, 0.0, 1.0);
}