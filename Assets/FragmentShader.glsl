/*
Title: Advanced Ray Tracer
File Name: FragmentShader.glsl
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

References:
https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-(Part-I)

Description:
This program serves to demonstrate the concept of ray tracing. This
builds off a previous Intermediate Ray Tracer, adding in reflections. 
There are four point lights, specular and diffuse lighting, and shadows. 
It is important to note that the light positions and triangles being 
rendered are all hardcoded in the shader itself. Usually, you would 
pass those values into the Fragment Shader via a Uniform Buffer.

WARNING: Framerate may suffer depending on your hardware. This is a normal 
problem with Ray Tracing. If it runs too slowly, try removing the second 
cube from the triangles array in the Fragment Shader (and also adjusting 
NUM_TRIANGLES accordingly). There are many optimization techniques out 
there, but ultimately Ray Tracing is not typically used for Real-Time 
rendering.
*/

#version 430 // Identifies the version of the shader, this line must be on a separate line from the rest of the shader code

// The uniform variables, these storing the camera position and the four corner rays of the camera's view.
uniform vec3 eye;
uniform vec3 ray00;
uniform vec3 ray01;
uniform vec3 ray10;
uniform vec3 ray11;

// The input textureCoord relative to the quad as given by the Vertex Shader.
in vec2 textureCoord;

// The output of the Fragment Shader, AKA the pixel color.
out vec4 color;

struct light 
{
	vec4 pos;
	vec4 color;
	float radius;
	float brightness;
	float junk1;
	float junk2;
};

// Create some constants
#define MAX_SCENE_BOUNDS 100.0

#define MAX_LIGHTS 1
#define MAX_MESHES 7
#define MAX_TRIANGLES_PER_MESH 1486 // biggest mesh is 1486 triangles
#define NUM_TRIANGLES_IN_SCENE 1554 // This is calculated in the console window

struct InTriangle 
{
	vec4 pos[3];
	vec4 uv[3];
	vec4 normal[3];
};

struct Mesh
{
	int numTriangles;
	int junk1;
	int junk2;
	int junk3;
	InTriangle t[MAX_TRIANGLES_PER_MESH];
};

// texture that we will use
uniform sampler2D textureTest[MAX_MESHES];

// A layout describing the vertex buffer.
layout(binding = 0) buffer vertexBlock
{
	Mesh m[MAX_MESHES];
};

layout (binding = 1) buffer lightBlock
{
	light lights[MAX_LIGHTS];
};

struct hitinfo
{
	vec3 point;
	int m;
	int t;
};

// Determines whether or not a ray in a given direction hits a given triangle.
// Returns -1.0 if it does not; otherwise returns the value t at which the ray hits the triangle, which can be used to determine the point of collision.
// p is point on ray, d is ray direction, v0, v1, and v2 are points of the triangle.
float rayIntersectsTriangle(vec3 p, vec3 d, vec3 v0, vec3 v1, vec3 v2)
{
	vec3 e1,e2,h,s,q;
	float a,f,u,v, t;

	// Get two edges of triangle
	e1 = vec3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z);
	e2 = vec3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z);
	
	// Cross ray direction with triangle edge
	h = cross(d, e2);
	
	// Dot the other triangle edge with the above cross product
	a = dot(e1, h);

	// If a is zero or realy close to zero, then there's no collision.
	if (a > -0.00001 && a < 0.00001)
	{
		return -1.0;
	}

	// Take the inverse of a.
	f = 1/a;
	
	// Get vector from first triangle vertex toward cameraPos (or in the scope of this function, the vec3 p that is a point on the ray direction)
	s = vec3(p.x - v0.x, p.y - v0.y, p.z - v0.z);
	
	// Dot your s value with your h value from earlier (cross(d, e2)), then multiply by the inverse of a.
	u = f * dot(s, h);

	// If this value is not between 0 and 1, then there's no collision.
	if (u < 0.0 || u > 1.0)
	{
		return -1.0;
	}

	// Cross your s value with edge 1 (e1).
	q = cross(s, e1);

	// Dot the ray direction with this new q value, and then multiply by the inverse of a.
	v = f * dot(d, q);

	// If v is less than 0, or u + v are greater than 1, then there's no collision.
	if (v < 0.0 || u + v > 1.0)
	{
		return -1.0;
	}

	// At this stage we can compute t to find out where the intersection point is on the line
	t = f * dot(e2, q);

	// If t is greater than zero
	if (t > 0.00001)
	{
		// The ray does intersect the triangle, and we return the t value.
		return t;
	}
	
	// Otherwise, there is a line intersection, but not a ray intersection, so we return -1.0.
	return -1.0;
}

// Given an origin point, a direction, and a variable to pass information back out to, this will test a ray against every triangle in the scene.
// It will then return true or false, based on whether or not the ray collided with anything.
// If it did, then the hitinfo object will be filled with a point of collision and an index referring to which triangle it intersects with first.
bool intersectTriangles(vec3 origin, vec3 dir, out hitinfo info)
{
	// Start our variables for determining the closest triangle.
	// Smallest will be the smallest distance between the origin point and the point of collision.
	// Found just determines whether or not there was a collision at all.
	float smallest = MAX_SCENE_BOUNDS;
	bool found = false;

	for(int i = 0; i < MAX_MESHES; i++)
	{
		// Placeholder for future optimization
		// Check if ray collides with mesh's hitbox
		// before checking the triangles of the mesh
		if(true)
		{
			// check all triangles in the mesh
			for(int j = 0; j < m[i].numTriangles; j++)
			{
				InTriangle t = m[i].t[j];

				// If the dot product is 0, the vectors are 90 degrees apart (orthogonal or perpendicular).
				// If the dot product is less than 0, the vectors are more than 90 degrees apart.
				// If the dot product is greater than 0, the vectors are less than 90 degrees apart.

				// If our direction can't hit the triangle
				// skip this triangle, and check the next triangle

				// We determine this, if all vertex normals on the triangle point
				// away from the rays that are moving towards the triangle

				// Compute distance d using above function to determine how far along the ray the triangle collides.
				float d = rayIntersectsTriangle(origin, dir, t.pos[0].xyz, t.pos[1].xyz, t.pos[2].xyz);

				// If t = -1.0 then there was no intersection, we also ignore it if t is not < smallest, as that would mean we already found a triangle that 
				// was closer (and thus collides first).
				if(d != -1.0 && d < smallest)
				{
					// This t becomes the new smallest.
					smallest = d;

					// color can be found via index as can the normal
					// Thus, we just pass out a point of collision using t and the triangle index.
					info.point = origin + (dir * d);
					info.m = i;
					info.t = j;

					// Make sure we set found to true, signifying that the ray collided with something.
					found = true;
				}
			}
		}
	}

	return found;
}

bool rayHitCar(vec3 origin, vec3 dir, out hitinfo info)
{
	// Start our variables for determining the closest triangle.
	// Smallest will be the smallest distance between the origin point and the point of collision.
	// Found just determines whether or not there was a collision at all.
	float smallest = MAX_SCENE_BOUNDS;
	bool found = false;

	// only check the car and tires
	for(int i = 2; i < MAX_MESHES; i++)
	{
		// Placeholder for future optimization
		// Check if ray collides with mesh's hitbox
		// before checking the triangles of the mesh
		if(true)
		{
			// check all triangles in the mesh
			for(int j = 0; j < m[i].numTriangles; j++)
			{
				InTriangle t = m[i].t[j];

				// Compute distance d using above function to determine how far along the ray the triangle collides.
				float d = rayIntersectsTriangle(origin, dir, t.pos[0].xyz, t.pos[1].xyz, t.pos[2].xyz);

				if(d != -1.0 && d < smallest)
				{
					// This t becomes the new smallest.
					smallest = d;

					// color can be found via index as can the normal
					// Thus, we just pass out a point of collision using t and the triangle index.
					info.point = origin + (dir * d);
					info.m = i;
					info.t = j;

					return true;
				}
			}
		}
	}

	return found;
}

vec3 GetInterpolatedNormal(vec3 pointHit, vec3 p1, vec3 p2, vec3 p3, vec3 n1, vec3 n2, vec3 n3)
{
	// Given the 3 points on the triangle,
	// Given the 1 point inside the triangle,
	// Given the 3 normals on the triangle,
	// Find the interpolated normal for that point

	vec3 a = p1;
	vec3 b = p2;
	vec3 c = p3;
	vec3 p = pointHit;

	vec3 v0 = b - a;
	vec3 v1 = c - a; 
	vec3 v2 = p - a;

	float d00 = dot(v0, v0);
	float d01 = dot(v0, v1);
	float d11 = dot(v1, v1);
	float d20 = dot(v2, v0);
	float d21 = dot(v2, v1);
	float denom = d00 * d11 - d01 * d01;
	
	// Barycentric Coordinates of point
	float v = (d11 * d20 - d01 * d21) / denom;
	float w = (d00 * d21 - d01 * d20) / denom;
	float u = 1.0f - v - w;

	// Interpolate Normal
	// Interpolate Normal
	vec3 newNormal = 
		u*n1 + 
		v*n2 + 
		w*n3;

	// This is calculated incorrectly
	// It needs to be fixed so that
	// The car can look smooth
	return normalize(newNormal);
}

vec2 GetInterpolatedUV(vec3 pointHit, vec3 p1, vec3 p2, vec3 p3, vec2 t1, vec2 t2, vec2 t3)
{
	// Given the 3 points on the triangle,
	// Given the 1 point inside the triangle,
	// Given the 3 normals on the triangle,
	// Find the interpolated normal for that point

	vec3 a = p1;
	vec3 b = p2;
	vec3 c = p3;
	vec3 p = pointHit;

	vec3 v0 = b - a;
	vec3 v1 = c - a; 
	vec3 v2 = p - a;

	float d00 = dot(v0, v0);
	float d01 = dot(v0, v1);
	float d11 = dot(v1, v1);
	float d20 = dot(v2, v0);
	float d21 = dot(v2, v1);
	float denom = d00 * d11 - d01 * d01;
	
	// Barycentric Coordinates of point
	float v = (d11 * d20 - d01 * d21) / denom;
	float w = (d00 * d21 - d01 * d20) / denom;
	float u = 1.0f - v - w;

	// Interpolate UV
	vec2 newUV = 
		u*t1 + 
		v*t2 + 
		w*t3;

	// return the texture coordinate
	return newUV;
}

vec4 getSurfaceColor(hitinfo i)
{
	InTriangle t = m[i.m].t[i.t];

	vec2 uv = GetInterpolatedUV(
		i.point,
		t.pos[0].xyz,
		t.pos[1].xyz,
		t.pos[2].xyz,
		vec2(t.uv[0]),
		vec2(t.uv[1]),
		vec2(t.uv[2])
	);

	return texture(textureTest[i.m], uv.xy);
}

vec3 addLightColorToPixColor(light L, vec3 dirRayToPoint, hitinfo rayHitPoint, bool checkShadows)
{
	// get direction from point to light
	vec3 pointToLight = L.pos.xyz - rayHitPoint.point;
	
	// Get the distance from point on surface to light
	float dist = length(pointToLight);

	// if the pixel is outside the range of the 
	// light, return 0. Don't process the light 
	// if the light doesn't touch the pixel anyways
	if(dist > L.radius)
		return vec3(0);

	// normalize the distance, to get direction
	pointToLight = normalize(pointToLight);

	// Create a hitinfo object to store the collision.
	hitinfo lightHitPoint;

	// Now we check to see if any polygons are standing between the point
	// that the ray hit, and the light. If a polygon blocks this new ray from
	// the light, then don't light this pixel (shadow). Otherwise, light it.
	// If you do NOT want shadows, delete the if-statment
	if(checkShadows)
	{
		if(rayHitCar(L.pos.xyz, -pointToLight, lightHitPoint))
		{
			// If the distance from the point to the light is farther than the distance from the light to the first surface it hits
			if(dist - length(L.pos.xyz - lightHitPoint.point) > 0.1)
			{
				// Then this is in shadow, since the light is hitting another object first.
				return vec3(0);
			}
		}
	}

	hitinfo i = rayHitPoint;
	InTriangle t = m[i.m].t[i.t];

	// Get the interpolated normal for the Point that is hit on the triangle by the ray
	// This normal will be interpolated between all three vertex normals
	vec3 normal = GetInterpolatedNormal(
		rayHitPoint.point, 
		t.pos[0].xyz,
		t.pos[1].xyz,
		t.pos[2].xyz,
		t.normal[0].xyz,
		t.normal[1].xyz,
		t.normal[2].xyz);

	// Get a reflection vector bouncing the light ray off the surface of the triangle.
	// Used for specular light calculations.
	vec3 reflectedRayToPoint = reflect(pointToLight, normal);

	// get the dot product, just like the basic tutorials
	float NdotL = dot(normal, pointToLight);

	// clamp the color
	NdotL = clamp(NdotL, 0.0, 1.0);

	// Formula for range-based attenuation
	float atten = 1.0 - (dist*dist) / (L.radius*L.radius);
	
	// clamp the attenuation
	atten = clamp(atten, 0.0, 1.0);

	// Get the final color of the light on the pixel
	float diffuse = NdotL;

	// brightness of light
	vec3 brightness = L.brightness * L.color.xyz * atten;

	// color of surface
	vec4 surfaceColor = getSurfaceColor(rayHitPoint);

	// Return our diffuse light and specular (we do white light, for specula) and factor in the reflectionLevel and lightIntensity.
	return surfaceColor.xyz * brightness * diffuse;
}

// Trace a ray from an origin point in a given direction and calculate/return the color value of the point that ray hits.
vec4 trace(vec3 origin, vec3 dirEyeToTriangle)
{
	// Create object to get our hitinfo back out of the intersectTriangles function.
	hitinfo eyeHitTriangle;

	// If this ray intersects any of the triangles in the scene.
	if (intersectTriangles(origin, dirEyeToTriangle, eyeHitTriangle))
	{
		vec4 surfaceColor = getSurfaceColor(eyeHitTriangle);
		
		// If you're aiming for a real-time render
		// you can return color here, to disable
		// all lighting effects
		// return surfaceColor;

		// Create a pixColor variable, which will determine the output color of this pixel. Start with some ambient light.
		vec3 pixColor = surfaceColor.xyz * 0.1;

		// skybox
		if(eyeHitTriangle.m == 1)
		{
			return surfaceColor;
		}

		// plane
		if(eyeHitTriangle.m == 0)
			pixColor += addLightColorToPixColor(lights[0], dirEyeToTriangle, eyeHitTriangle, true);
		
		// car and tires
		else
			pixColor += addLightColorToPixColor(lights[0], dirEyeToTriangle, eyeHitTriangle, false);

		// Return the final pixel color.		
		return vec4(pixColor.rgb, 1.0);
	}

	// If the ray doesn't hit any triangles, then this ray sees nothing and thus:
	// Return 0, which can be replaced with skybox
	return vec4(vec3(0), 1.0);
}

void main(void)
{
	// Keep in mind, "textureCoord" does not actually mean textures being mapped onto the surface of geometry,
	// UV coordinates and textures will come in a future tutorial

	// This is easy. Using the textureCoord, you interpolate between the four corner rays to get a ray (dir) that goes through a point in the screen.
	// For your mental image, imagine this shader runes once for every single pixel on your screen.
	// Every time it runs, dir is the ray that goes from the camera's position, through the pixel that it is rendering. Thus, we are tracing a ray through every pixel 
	// on the screen to determine what to render.
	vec2 pos = textureCoord;
	vec3 dir = normalize(mix(mix(ray00, ray01, pos.y), mix(ray10, ray11, pos.y), pos.x));
	color = trace(eye, dir);
}