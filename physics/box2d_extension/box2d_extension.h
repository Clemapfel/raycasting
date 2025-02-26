#include <box2d/box2d.h>
#include <stdbool.h>

// MISC

BOX2D_EXPORT b2Transform b2MakeTransform(float x, float y, float angle_rad);

// THREADING

BOX2D_EXPORT typedef struct b2TaskData {
    b2TaskCallback* callback;
    void* context;
} b2TaskData;

BOX2D_EXPORT typedef struct b2UserContext {
    void* scheduler;
    void* tasks[256];
    b2TaskData task_data[256];
    int n_tasks;
} b2UserContext;

BOX2D_EXPORT void b2InvokeTask(uint32_t start, uint32_t end, uint32_t threadIndex, void* context);

// RAY CAST

//BOX2D_EXPORT typedef float b2CastResultFcn( b2ShapeId shapeId, b2Vec2 point, b2Vec2 normal, float fraction, void* context );
BOX2D_EXPORT typedef float b2CastResultFcnWrapper( b2ShapeId* shapeId, b2Vec2* point, b2Vec2* normal, float fraction);

BOX2D_EXPORT float b2CastRayWrapperCallback(b2ShapeId shape_id, b2Vec2 point, b2Vec2 normal, float fraction, void* context );

BOX2D_EXPORT void b2World_CastRayWrapper(
    b2WorldId world,
    b2Vec2 origin,
    b2Vec2 translation,
    b2QueryFilter filter,
    b2CastResultFcnWrapper* callback
);

// OVERLAP

// BOX2D_EXPORT typedef bool b2OverlapResultFcn(b2ShapeId shapeId);
BOX2D_EXPORT typedef bool b2OverlapResultFcnWrapper(b2ShapeId* shapeId);
BOX2D_EXPORT bool b2OverlapResultWrapperCallback(b2ShapeId, void* context);

BOX2D_EXPORT void b2World_OverlapCircleWrapper(
    b2WorldId world,
    b2Circle* circle,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

BOX2D_EXPORT void b2World_OverlapAABBWrapper(
    b2WorldId world,
    b2AABB aabb,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

BOX2D_EXPORT void b2World_OverlapPolygonWrapper(
    b2WorldId world,
    b2Polygon* polygon,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

BOX2D_EXPORT void b2World_OverlapCapsuleWrapper(
    b2WorldId world,
    b2Capsule* capsule,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

// DEBUG DRAW

BOX2D_EXPORT void b2HexColorToRGB(int hexColor, float* red, float* green, float* blue);

BOX2D_EXPORT typedef void b2DrawPolygonFcn(const b2Vec2* vertices, int vertex_count, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawSolidPolygonFcn(b2Transform* transform, const b2Vec2* vertices, int vertex_count, float radius, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawCircleFcn(b2Vec2* center, float radius, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawSolidCircleFcn(b2Transform* transform, float radius, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawSolidCapsuleFcn(b2Vec2* p1, b2Vec2* p2, float radius, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawSegmentFcn(b2Vec2* p1, b2Vec2* p2, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawTransformFcn(b2Transform*);
BOX2D_EXPORT typedef void b2DrawPointFcn(b2Vec2* p, float size, float red, float green, float blue);
BOX2D_EXPORT typedef void b2DrawString(b2Vec2* p, const char* s);

BOX2D_EXPORT typedef struct b2DebugDrawContext {
    b2DrawPolygonFcn* draw_polygon;
    b2DrawSolidPolygonFcn* draw_solid_polygon;
    b2DrawCircleFcn* draw_circle;
    b2DrawSolidCircleFcn* draw_solid_circle;
    b2DrawSolidCapsuleFcn* draw_solid_capsule;
    b2DrawSegmentFcn* draw_segment;
    b2DrawTransformFcn* draw_transform;
    b2DrawPointFcn* draw_point;
    b2DrawString* draw_string;
} b2DebugDrawContext;

BOX2D_EXPORT void b2DebugDraw_DrawPolygon(const b2Vec2* vertices, int vertexCount, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawSolidPolygon(b2Transform transform, const b2Vec2* vertices, int vertexCount, float radius, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawCircle(b2Vec2 center, float radius, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawSolidCircle(b2Transform transform, float radius, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawSolidCapsule(b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawSegment(b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context_ptr);
BOX2D_EXPORT void b2DebugDraw_DrawTransform(b2Transform transform, void* context);
BOX2D_EXPORT void b2DebugDraw_DrawPoint(b2Vec2 p, float size, b2HexColor color, void* context);
BOX2D_EXPORT void b2DebugDraw_DrawString(b2Vec2 p, const char* s, void* context);

BOX2D_EXPORT b2DebugDraw b2CreateDebugDraw(
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
);