#include "box2d_extension.h"
#include <stdio.h>
#include <stdlib.h>

// MISC

b2Transform b2MakeTransform(float x, float y, float angle_rad) {
    b2Transform out;
    b2Vec2 p;
    p.x = x;
    p.y = y;
    out.p = p;
    out.q = b2MakeRot(angle_rad);
    return out;
}

// THREADS

void b2InvokeTask(uint32_t start, uint32_t end, uint32_t threadIndex, void* context)
{
    b2TaskData* data = (b2TaskData*) context;
    data->callback(start, end, threadIndex, data->context);
}

// RAY CAST

float b2CastRayWrapperCallback(b2ShapeId shape_id, b2Vec2 point, b2Vec2 normal, float fraction, void* context ) {
    return ((b2CastResultFcnWrapper*) context)(&shape_id, &point, &normal, fraction);
}

void b2World_CastRayWrapper(b2WorldId world, b2Vec2 origin, b2Vec2 translation, b2QueryFilter filter, b2CastResultFcnWrapper* callback) {
    fprintf(stderr, "called");
    b2World_CastRay(world, origin, translation, filter, b2CastRayWrapperCallback, callback);
}

// OVERLAP

bool b2OverlapResultWrapperCallback(b2ShapeId shape, void* context) {
    return ((b2OverlapResultFcnWrapper*) context)(&shape);
}

void b2World_OverlapCircleWrapper(b2WorldId world, b2Circle* circle, b2Transform transform, b2QueryFilter filter, b2OverlapResultFcnWrapper* callback) {
    b2World_OverlapCircle(world, circle, transform, filter, b2OverlapResultWrapperCallback, (void*) callback);
}

void b2World_OverlapAABBWrapper(b2WorldId world, b2AABB aabb, b2QueryFilter filter, b2OverlapResultFcnWrapper* callback) {
    b2World_OverlapAABB(world, aabb, filter, b2OverlapResultWrapperCallback, (void*) callback);
}

void b2World_OverlapPolygonWrapper(b2WorldId world, b2Polygon* polygon, b2Transform transform, b2QueryFilter filter, b2OverlapResultFcnWrapper* callback) {
    b2World_OverlapPolygon(world, polygon, transform, filter, b2OverlapResultWrapperCallback, (void*) callback);
}

void b2World_OverlapCapsuleWrapper(b2WorldId world, b2Capsule* polygon, b2Transform transform, b2QueryFilter filter, b2OverlapResultFcnWrapper* callback) {
    b2World_OverlapCapsule(world, polygon, transform, filter, b2OverlapResultWrapperCallback, (void*) callback);
}

// DRAW

void b2HexColorToRGB(int hexColor, float* red, float* green, float* blue) {
    *red = ((hexColor >> 16) & 0xFF) / 255.0f;
    *green = ((hexColor >> 8) & 0xFF) / 255.0f;
    *blue = (hexColor & 0xFF) / 255.0f;
}

void b2DebugDraw_DrawPolygon(const b2Vec2* vertices, int vertex_count, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_polygon(vertices, vertex_count, red, green, blue);
}

void b2DebugDraw_DrawSolidPolygon(b2Transform transform, const b2Vec2* vertices, int vertex_count, float radius, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_solid_polygon(&transform, vertices, vertex_count, radius, red, green, blue);
}

void b2DebugDraw_DrawCircle(b2Vec2 center, float radius, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_circle(&center, radius, red, green, blue);
}

void b2DebugDraw_DrawSolidCircle(b2Transform transform, float radius, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_solid_circle(&transform, radius, red, green, blue);
}

void b2DebugDraw_DrawSolidCapsule(b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_solid_capsule(&p1, &p2, radius, red, green, blue);
}

void b2DebugDraw_DrawSegment(b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_segment(&p1, &p2, red, green, blue);
}

void b2DebugDraw_DrawTransform(b2Transform transform, void* context_ptr) {
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_transform(&transform);
}

void b2DebugDraw_DrawPoint(b2Vec2 p, float size, b2HexColor color, void* context_ptr) {
    float red, green, blue;
    b2HexColorToRGB(color, &red, &green, &blue);
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_point(&p, size, red, green, blue);
}

void b2DebugDraw_DrawString(b2Vec2 p, const char* s, void* context_ptr) {
    b2DebugDrawContext* context = (b2DebugDrawContext*) context_ptr;
    context->draw_string(&p, s);
}

b2DebugDraw b2CreateDebugDraw(
    b2DrawPolygonFcn* draw_polygon,
    b2DrawSolidPolygonFcn* draw_solid_polygon,
    b2DrawCircleFcn* draw_circle,
    b2DrawSolidCircleFcn* draw_solid_circle,
    b2DrawSolidCapsuleFcn* draw_solid_capsule,
    b2DrawSegmentFcn* draw_segment,
    b2DrawTransformFcn* draw_transform,
    b2DrawPointFcn* draw_point,
    b2DrawString* draw_string,
    bool draw_shapes,
    bool draw_joints,
    bool draw_joints_extra,
    bool draw_aabb,
    bool draw_mass,
    bool draw_contacts,
    bool draw_graph_colors,
    bool draw_contact_normals,
    bool draw_contact_impulses,
    bool draw_friction_impulses
) {
    b2DebugDraw draw = b2DefaultDebugDraw();
    draw.DrawPolygon = b2DebugDraw_DrawPolygon;
    draw.DrawSolidPolygon = b2DebugDraw_DrawSolidPolygon;
    draw.DrawCircle = b2DebugDraw_DrawCircle;
    draw.DrawSolidCircle = b2DebugDraw_DrawSolidCircle;
    draw.DrawSolidCapsule = b2DebugDraw_DrawSolidCapsule;
    draw.DrawSegment = b2DebugDraw_DrawSegment;
    draw.DrawTransform = b2DebugDraw_DrawTransform;
    draw.DrawPoint = b2DebugDraw_DrawPoint;
    draw.DrawString = b2DebugDraw_DrawString;

    draw.useDrawingBounds = false;
    draw.drawShapes = draw_shapes;
    draw.drawJoints = draw_joints;
    draw.drawJointExtras = draw_joints_extra;
    draw.drawAABBs = draw_aabb;
    draw.drawMass = draw_mass;
    draw.drawContacts = draw_contacts;
    draw.drawGraphColors = draw_graph_colors;
    draw.drawContactNormals = draw_contact_normals;
    draw.drawContactImpulses = draw_contact_impulses;
    draw.drawFrictionImpulses = draw_friction_impulses;

    b2DebugDrawContext* context = (b2DebugDrawContext*) malloc(sizeof(b2DebugDrawContext));
    context->draw_polygon = draw_polygon;
    context->draw_solid_polygon = draw_solid_polygon;
    context->draw_circle = draw_circle;
    context->draw_solid_circle = draw_solid_circle;
    context->draw_solid_capsule = draw_solid_capsule;
    context->draw_segment = draw_segment;
    context->draw_transform = draw_transform;
    context->draw_point = draw_point;
    context->draw_string = draw_string;

    draw.context = (void*) context;
    return draw;
}
