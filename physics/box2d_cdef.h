/// 2D vector
/// This can be used to represent a point or free vector
typedef struct b2Vec2
{
    /// coordinates
    float x, y;
} b2Vec2;

/// 2D rotation
/// This is similar to using a complex number for rotation
typedef struct b2Rot
{
    /// cosine and sine
    float c, s;
} b2Rot;

b2Rot b2MakeRot(float angle);

/// A 2D rigid transform
typedef struct b2Transform
{
    b2Vec2 p;
    b2Rot q;
} b2Transform;

/// A 2-by-2 Matrix
typedef struct b2Mat22
{
    /// columns
    b2Vec2 cx, cy;
} b2Mat22;

/// Axis-aligned bounding box
typedef struct b2AABB
{
    b2Vec2 lowerBound;
    b2Vec2 upperBound;
} b2AABB;

/// Box2D bases all length units on meters, but you may need different units for your game.
/// You can set this value to use different units. This should be done at application startup
///	and only modified once. Default value is 1.
///	@warning This must be modified before any calls to Box2D
void b2SetLengthUnitsPerMeter( float lengthUnits );

/// Get the current length units per meter.
float b2GetLengthUnitsPerMeter( void );

/// Task interface
/// This is prototype for a Box2D task. Your task system is expected to invoke the Box2D task with these arguments.
/// The task spans a range of the parallel-for: [startIndex, endIndex)
/// The worker index must correctly identify each worker in the user thread pool, expected in [0, workerCount).
///	A worker must only exist on only one thread at a time and is analogous to the thread index.
/// The task context is the context pointer sent from Box2D when it is enqueued.
///	The startIndex and endIndex are expected in the range [0, itemCount) where itemCount is the argument to b2EnqueueTaskCallback
/// below. Box2D expects startIndex < endIndex and will execute a loop like this:
///
///	@code{.c}
/// for (int i = startIndex; i < endIndex; ++i)
///	{
///		DoWork();
///	}
///	@endcode
///	@ingroup world
typedef void b2TaskCallback( int32_t startIndex, int32_t endIndex, uint32_t workerIndex, void* taskContext );

/// These functions can be provided to Box2D to invoke a task system. These are designed to work well with enkiTS.
/// Returns a pointer to the user's task object. May be nullptr. A nullptr indicates to Box2D that the work was executed
///	serially within the callback and there is no need to call b2FinishTaskCallback.
///	The itemCount is the number of Box2D work items that are to be partitioned among workers by the user's task system.
///	This is essentially a parallel-for. The minRange parameter is a suggestion of the minimum number of items to assign
///	per worker to reduce overhead. For example, suppose the task is small and that itemCount is 16. A minRange of 8 suggests
///	that your task system should split the work items among just two workers, even if you have more available.
///	In general the range [startIndex, endIndex) send to b2TaskCallback should obey:
///	endIndex - startIndex >= minRange
///	The exception of course is when itemCount < minRange.
///	@ingroup world
typedef void* b2EnqueueTaskCallback( b2TaskCallback* task, int32_t itemCount, int32_t minRange, void* taskContext,
void* userContext );

/// Finishes a user task object that wraps a Box2D task.
///	@ingroup world
typedef void b2FinishTaskCallback( void* userTask, void* userContext );

/// World id references a world instance. This should be treated as an opaque handle.
typedef struct b2WorldId
{
    uint16_t index1;
    uint16_t revision;
} b2WorldId;

/// Body id references a body instance. This should be treated as an opaque handle.
typedef struct b2BodyId
{
    int32_t index1;
    uint16_t world0;
    uint16_t revision;
} b2BodyId;

/// Shape id references a shape instance. This should be treated as an opaque handle.
typedef struct b2ShapeId
{
    int32_t index1;
    uint16_t world0;
    uint16_t revision;
} b2ShapeId;

/// Joint id references a joint instance. This should be treated as an opaque handle.
typedef struct b2JointId
{
    int32_t index1;
    uint16_t world0;
    uint16_t revision;
} b2JointId;

/// Chain id references a chain instances. This should be treated as an opaque handle.
typedef struct b2ChainId
{
    int32_t index1;
    uint16_t world0;
    uint16_t revision;
} b2ChainId;


/// Result from b2World_RayCastClosest
/// @ingroup world
typedef struct b2RayResult
{
    b2ShapeId shapeId;
    b2Vec2 point;
    b2Vec2 normal;
    float fraction;
    bool hit;
} b2RayResult;

/// World definition used to create a simulation world.
/// Must be initialized using b2DefaultWorldDef().
/// @ingroup world
typedef struct b2WorldDef
{
    /// Gravity vector. Box2D has no up-vector defined.
    b2Vec2 gravity;

    /// Restitution velocity threshold, usually in m/s. Collisions above this
    /// speed have restitution applied (will bounce).
    float restitutionThreshold;

    /// This parameter controls how fast overlap is resolved and has units of meters per second
    float contactPushoutVelocity;

    /// Threshold velocity for hit events. Usually meters per second.
    float hitEventThreshold;

    /// Contact stiffness. Cycles per second.
    float contactHertz;

    /// Contact bounciness. Non-dimensional.
    float contactDampingRatio;

    /// Joint stiffness. Cycles per second.
    float jointHertz;

    /// Joint bounciness. Non-dimensional.
    float jointDampingRatio;

    /// Maximum linear velocity. Usually meters per second.
    float maximumLinearVelocity;

    /// Can bodies go to sleep to improve performance
    bool enableSleep;

    /// Enable continuous collision
    bool enableContinuous;

    /// Number of workers to use with the provided task system. Box2D performs best when using only
    ///	performance cores and accessing a single L2 cache. Efficiency cores and hyper-threading provide
    ///	little benefit and may even harm performance.
    int32_t workerCount;

    /// Function to spawn tasks
    b2EnqueueTaskCallback* enqueueTask;

    /// Function to finish a task
    b2FinishTaskCallback* finishTask;

    /// User context that is provided to enqueueTask and finishTask
    void* userTaskContext;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2WorldDef;

/// Use this to initialize your world definition
/// @ingroup world
b2WorldDef b2DefaultWorldDef( void );

/// The body simulation type.
/// Each body is one of these three types. The type determines how the body behaves in the simulation.
/// @ingroup body
typedef enum b2BodyType
{
    /// zero mass, zero velocity, may be manually moved
    b2_staticBody = 0,

    /// zero mass, velocity set by user, moved by solver
    b2_kinematicBody = 1,

    /// positive mass, velocity determined by forces, moved by solver
    b2_dynamicBody = 2,

    /// number of body types
    b2_bodyTypeCount,
} b2BodyType;

/// A body definition holds all the data needed to construct a rigid body.
/// You can safely re-use body definitions. Shapes are added to a body after construction.
///	Body definitions are temporary objects used to bundle creation parameters.
/// Must be initialized using b2DefaultBodyDef().
/// @ingroup body
typedef struct b2BodyDef
{
    /// The body type: static, kinematic, or dynamic.
    b2BodyType type;

    /// The initial world position of the body. Bodies should be created with the desired position.
    /// @note Creating bodies at the origin and then moving them nearly doubles the cost of body creation, especially
    ///	if the body is moved after shapes have been added.
    b2Vec2 position;

    /// The initial world rotation of the body. Use b2MakeRot() if you have an angle.
    b2Rot rotation;

    /// The initial linear velocity of the body's origin. Typically in meters per second.
    b2Vec2 linearVelocity;

    /// The initial angular velocity of the body. Radians per second.
    float angularVelocity;

    /// Linear damping is use to reduce the linear velocity. The damping parameter
    /// can be larger than 1 but the damping effect becomes sensitive to the
    /// time step when the damping parameter is large.
    ///	Generally linear damping is undesirable because it makes objects move slowly
    ///	as if they are floating.
    float linearDamping;

    /// Angular damping is use to reduce the angular velocity. The damping parameter
    /// can be larger than 1.0f but the damping effect becomes sensitive to the
    /// time step when the damping parameter is large.
    ///	Angular damping can be use slow down rotating bodies.
    float angularDamping;

    /// Scale the gravity applied to this body. Non-dimensional.
    float gravityScale;

    /// Sleep velocity threshold, default is 0.05 meter per second
    float sleepThreshold;

    /// Use this to store application specific body data.
    void* userData;

    /// Set this flag to false if this body should never fall asleep.
    bool enableSleep;

    /// Is this body initially awake or sleeping?
    bool isAwake;

    /// Should this body be prevented from rotating? Useful for characters.
    bool fixedRotation;

    /// Treat this body as high speed object that performs continuous collision detection
    /// against dynamic and kinematic bodies, but not other bullet bodies.
    ///	@warning Bullets should be used sparingly. They are not a solution for general dynamic-versus-dynamic
    ///	continuous collision. They may interfere with joint constraints.
    bool isBullet;

    /// Used to disable a body. A disabled body does not move or collide.
    bool isEnabled;

    /// Automatically compute mass and related properties on this body from shapes.
    /// Triggers whenever a shape is add/removed/changed. Default is true.
    bool automaticMass;

    /// This allows this body to bypass rotational speed limits. Should only be used
    ///	for circular objects, like wheels.
    bool allowFastRotation;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2BodyDef;

/// Use this to initialize your body definition
/// @ingroup body
b2BodyDef b2DefaultBodyDef( void );

/// This is used to filter collision on shapes. It affects shape-vs-shape collision
///	and shape-versus-query collision (such as b2World_CastRay).
/// @ingroup shape
typedef struct b2Filter
{
    /// The collision category bits. Normally you would just set one bit. The category bits should
    ///	represent your application object types. For example:
    ///	@code{.cpp}
    ///	enum MyCategories
    ///	{
    ///	   Static  = 0x00000001,
    ///	   Dynamic = 0x00000002,
    ///	   Debris  = 0x00000004,
    ///	   Player  = 0x00000008,
    ///	   // etc
    /// };
    ///	@endcode
    uint64_t categoryBits;

    /// The collision mask bits. This states the categories that this
    /// shape would accept for collision.
    ///	For example, you may want your player to only collide with static objects
    ///	and other players.
    ///	@code{.c}
    ///	maskBits = Static | Player;
    ///	@endcode
    uint64_t maskBits;

    /// Collision groups allow a certain group of objects to never collide (negative)
    /// or always collide (positive). A group index of zero has no effect. Non-zero group filtering
    /// always wins against the mask bits.
    ///	For example, you may want ragdolls to collide with other ragdolls but you don't want
    ///	ragdoll self-collision. In this case you would give each ragdoll a unique negative group index
    ///	and apply that group index to all shapes on the ragdoll.
    int32_t groupIndex;
} b2Filter;

/// Use this to initialize your filter
/// @ingroup shape
b2Filter b2DefaultFilter( void );

/// The query filter is used to filter collisions between queries and shapes. For example,
///	you may want a ray-cast representing a projectile to hit players and the static environment
///	but not debris.
/// @ingroup shape
typedef struct b2QueryFilter
{
    /// The collision category bits of this query. Normally you would just set one bit.
    uint64_t categoryBits;

    /// The collision mask bits. This states the shape categories that this
    /// query would accept for collision.
    uint64_t maskBits;
} b2QueryFilter;

/// Use this to initialize your query filter
/// @ingroup shape
b2QueryFilter b2DefaultQueryFilter( void );

/// Shape type
/// @ingroup shape
typedef enum b2ShapeType
{
    /// A circle with an offset
    b2_circleShape,

    /// A capsule is an extruded circle
    b2_capsuleShape,

    /// A line segment
    b2_segmentShape,

    /// A convex polygon
    b2_polygonShape,

    /// A line segment owned by a chain shape
    b2_chainSegmentShape,

    /// The number of shape types
    b2_shapeTypeCount
} b2ShapeType;

/// Used to create a shape.
/// This is a temporary object used to bundle shape creation parameters. You may use
///	the same shape definition to create multiple shapes.
/// Must be initialized using b2DefaultShapeDef().
/// @ingroup shape
typedef struct b2ShapeDef
{
    /// Use this to store application specific shape data.
    void* userData;

    /// The Coulomb (dry) friction coefficient, usually in the range [0,1].
    float friction;

    /// The restitution (bounce) usually in the range [0,1].
    float restitution;

    /// The density, usually in kg/m^2.
    float density;

    /// Collision filtering data.
    b2Filter filter;

    /// Custom debug draw color.
    uint32_t customColor;

    /// A sensor shape generates overlap events but never generates a collision response.
    ///	Sensors do not collide with other sensors and do not have continuous collision.
    ///	Instead use a ray or shape cast for those scenarios.
    bool isSensor;

    /// Enable sensor events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
    bool enableSensorEvents;

    /// Enable contact events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
    bool enableContactEvents;

    /// Enable hit events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
    bool enableHitEvents;

    /// Enable pre-solve contact events for this shape. Only applies to dynamic bodies. These are expensive
    ///	and must be carefully handled due to threading. Ignored for sensors.
    bool enablePreSolveEvents;

    /// Normally shapes on static bodies don't invoke contact creation when they are added to the world. This overrides
    ///	that behavior and causes contact creation. This significantly slows down static body creation which can be important
    ///	when there are many static shapes.
    /// This is implicitly always true for sensors.
    bool forceContactCreation;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2ShapeDef;

/// Use this to initialize your shape definition
/// @ingroup shape
b2ShapeDef b2DefaultShapeDef( void );

/// Used to create a chain of line segments. This is designed to eliminate ghost collisions with some limitations.
///	- chains are one-sided
///	- chains have no mass and should be used on static bodies
///	- chains have a counter-clockwise winding order
///	- chains are either a loop or open
/// - a chain must have at least 4 points
///	- the distance between any two points must be greater than b2_linearSlop
///	- a chain shape should not self intersect (this is not validated)
///	- an open chain shape has NO COLLISION on the first and final edge
///	- you may overlap two open chains on their first three and/or last three points to get smooth collision
///	- a chain shape creates multiple line segment shapes on the body
/// https://en.wikipedia.org/wiki/Polygonal_chain
/// Must be initialized using b2DefaultChainDef().
///	@warning Do not use chain shapes unless you understand the limitations. This is an advanced feature.
/// @ingroup shape
typedef struct b2ChainDef
{
    /// Use this to store application specific shape data.
    void* userData;

    /// An array of at least 4 points. These are cloned and may be temporary.
    const b2Vec2* points;

    /// The point count, must be 4 or more.
    int32_t count;

    /// The friction coefficient, usually in the range [0,1].
    float friction;

    /// The restitution (elasticity) usually in the range [0,1].
    float restitution;

    /// Contact filtering data.
    b2Filter filter;

    /// Indicates a closed chain formed by connecting the first and last points
    bool isLoop;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2ChainDef;

/// Use this to initialize your chain definition
/// @ingroup shape
b2ChainDef b2DefaultChainDef( void );


//! @cond
/// Profiling data. Times are in milliseconds.
typedef struct b2Profile
{
    float step;
    float pairs;
    float collide;
    float solve;
    float buildIslands;
    float solveConstraints;
    float prepareTasks;
    float solverTasks;
    float prepareConstraints;
    float integrateVelocities;
    float warmStart;
    float solveVelocities;
    float integratePositions;
    float relaxVelocities;
    float applyRestitution;
    float storeImpulses;
    float finalizeBodies;
    float splitIslands;
    float sleepIslands;
    float hitEvents;
    float broadphase;
    float continuous;
} b2Profile;

/// Counters that give details of the simulation size.
typedef struct b2Counters
{
    int32_t bodyCount;
    int32_t shapeCount;
    int32_t contactCount;
    int32_t jointCount;
    int32_t islandCount;
    int32_t stackUsed;
    int32_t staticTreeHeight;
    int32_t treeHeight;
    int32_t byteCount;
    int32_t taskCount;
    int32_t colorCounts[12];
} b2Counters;
//! @endcond

/// Joint type enumeration
///
/// This is useful because all joint types use b2JointId and sometimes you
/// want to get the type of a joint.
/// @ingroup joint
typedef enum b2JointType
{
    b2_distanceJoint,
    b2_motorJoint,
    b2_mouseJoint,
    b2_prismaticJoint,
    b2_revoluteJoint,
    b2_weldJoint,
    b2_wheelJoint,
} b2JointType;

/// Distance joint definition
///
/// This requires defining an anchor point on both
/// bodies and the non-zero distance of the distance joint. The definition uses
/// local anchor points so that the initial configuration can violate the
/// constraint slightly. This helps when saving and loading a game.
/// @ingroup distance_joint
typedef struct b2DistanceJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// The local anchor point relative to bodyA's origin
    b2Vec2 localAnchorA;

    /// The local anchor point relative to bodyB's origin
    b2Vec2 localAnchorB;

    /// The rest length of this joint. Clamped to a stable minimum value.
    float length;

    /// Enable the distance constraint to behave like a spring. If false
    ///	then the distance joint will be rigid, overriding the limit and motor.
    bool enableSpring;

    /// The spring linear stiffness Hertz, cycles per second
    float hertz;

    /// The spring linear damping ratio, non-dimensional
    float dampingRatio;

    /// Enable/disable the joint limit
    bool enableLimit;

    /// Minimum length. Clamped to a stable minimum value.
    float minLength;

    /// Maximum length. Must be greater than or equal to the minimum length.
    float maxLength;

    /// Enable/disable the joint motor
    bool enableMotor;

    /// The maximum motor force, usually in newtons
    float maxMotorForce;

    /// The desired motor speed, usually in meters per second
    float motorSpeed;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2DistanceJointDef;

/// Use this to initialize your joint definition
/// @ingroup distance_joint
b2DistanceJointDef b2DefaultDistanceJointDef( void );

/// A motor joint is used to control the relative motion between two bodies
///
/// A typical usage is to control the movement of a dynamic body with respect to the ground.
/// @ingroup motor_joint
typedef struct b2MotorJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// Position of bodyB minus the position of bodyA, in bodyA's frame
    b2Vec2 linearOffset;

    /// The bodyB angle minus bodyA angle in radians
    float angularOffset;

    /// The maximum motor force in newtons
    float maxForce;

    /// The maximum motor torque in newton-meters
    float maxTorque;

    /// Position correction factor in the range [0,1]
    float correctionFactor;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2MotorJointDef;

/// Use this to initialize your joint definition
/// @ingroup motor_joint
b2MotorJointDef b2DefaultMotorJointDef( void );

/// A mouse joint is used to make a point on a body track a specified world point.
///
/// This a soft constraint and allows the constraint to stretch without
/// applying huge forces. This also applies rotation constraint heuristic to improve control.
/// @ingroup mouse_joint
typedef struct b2MouseJointDef
{
    /// The first attached body.
    b2BodyId bodyIdA;

    /// The second attached body.
    b2BodyId bodyIdB;

    /// The initial target point in world space
    b2Vec2 target;

    /// Stiffness in hertz
    float hertz;

    /// Damping ratio, non-dimensional
    float dampingRatio;

    /// Maximum force, typically in newtons
    float maxForce;

    /// Set this flag to true if the attached bodies should collide.
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2MouseJointDef;

/// Use this to initialize your joint definition
/// @ingroup mouse_joint
b2MouseJointDef b2DefaultMouseJointDef( void );

/// Prismatic joint definition
///
/// This requires defining a line of motion using an axis and an anchor point.
/// The definition uses local anchor points and a local axis so that the initial
/// configuration can violate the constraint slightly. The joint translation is zero
/// when the local anchor points coincide in world space.
/// @ingroup prismatic_joint
typedef struct b2PrismaticJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// The local anchor point relative to bodyA's origin
    b2Vec2 localAnchorA;

    /// The local anchor point relative to bodyB's origin
    b2Vec2 localAnchorB;

    /// The local translation unit axis in bodyA
    b2Vec2 localAxisA;

    /// The constrained angle between the bodies: bodyB_angle - bodyA_angle
    float referenceAngle;

    /// Enable a linear spring along the prismatic joint axis
    bool enableSpring;

    /// The spring stiffness Hertz, cycles per second
    float hertz;

    /// The spring damping ratio, non-dimensional
    float dampingRatio;

    /// Enable/disable the joint limit
    bool enableLimit;

    /// The lower translation limit
    float lowerTranslation;

    /// The upper translation limit
    float upperTranslation;

    /// Enable/disable the joint motor
    bool enableMotor;

    /// The maximum motor force, typically in newtons
    float maxMotorForce;

    /// The desired motor speed, typically in meters per second
    float motorSpeed;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2PrismaticJointDef;

/// Use this to initialize your joint definition
/// @ingroupd prismatic_joint
b2PrismaticJointDef b2DefaultPrismaticJointDef( void );

/// Revolute joint definition
///
/// This requires defining an anchor point where the bodies are joined.
/// The definition uses local anchor points so that the
/// initial configuration can violate the constraint slightly. You also need to
/// specify the initial relative angle for joint limits. This helps when saving
/// and loading a game.
/// The local anchor points are measured from the body's origin
/// rather than the center of mass because:
/// 1. you might not know where the center of mass will be
/// 2. if you add/remove shapes from a body and recompute the mass, the joints will be broken
/// @ingroup revolute_joint
typedef struct b2RevoluteJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// The local anchor point relative to bodyA's origin
    b2Vec2 localAnchorA;

    /// The local anchor point relative to bodyB's origin
    b2Vec2 localAnchorB;

    /// The bodyB angle minus bodyA angle in the reference state (radians).
    /// This defines the zero angle for the joint limit.
    float referenceAngle;

    /// Enable a rotational spring on the revolute hinge axis
    bool enableSpring;

    /// The spring stiffness Hertz, cycles per second
    float hertz;

    /// The spring damping ratio, non-dimensional
    float dampingRatio;

    /// A flag to enable joint limits
    bool enableLimit;

    /// The lower angle for the joint limit in radians
    float lowerAngle;

    /// The upper angle for the joint limit in radians
    float upperAngle;

    /// A flag to enable the joint motor
    bool enableMotor;

    /// The maximum motor torque, typically in newton-meters
    float maxMotorTorque;

    /// The desired motor speed in radians per second
    float motorSpeed;

    /// Scale the debug draw
    float drawSize;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2RevoluteJointDef;

/// Use this to initialize your joint definition.
/// @ingroup revolute_joint
b2RevoluteJointDef b2DefaultRevoluteJointDef( void );

/// Weld joint definition
///
/// A weld joint connect to bodies together rigidly. This constraint provides springs to mimic
///	soft-body simulation.
/// @note The approximate solver in Box2D cannot hold many bodies together rigidly
/// @ingroup weld_joint
typedef struct b2WeldJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// The local anchor point relative to bodyA's origin
    b2Vec2 localAnchorA;

    /// The local anchor point relative to bodyB's origin
    b2Vec2 localAnchorB;

    /// The bodyB angle minus bodyA angle in the reference state (radians)
    float referenceAngle;

    /// Linear stiffness expressed as Hertz (cycles per second). Use zero for maximum stiffness.
    float linearHertz;

    /// Angular stiffness as Hertz (cycles per second). Use zero for maximum stiffness.
    float angularHertz;

    /// Linear damping ratio, non-dimensional. Use 1 for critical damping.
    float linearDampingRatio;

    /// Linear damping ratio, non-dimensional. Use 1 for critical damping.
    float angularDampingRatio;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2WeldJointDef;

/// Use this to initialize your joint definition
/// @ingroup weld_joint
b2WeldJointDef b2DefaultWeldJointDef( void );

/// Wheel joint definition
///
/// This requires defining a line of motion using an axis and an anchor point.
/// The definition uses local  anchor points and a local axis so that the initial
/// configuration can violate the constraint slightly. The joint translation is zero
/// when the local anchor points coincide in world space.
/// @ingroup wheel_joint
typedef struct b2WheelJointDef
{
    /// The first attached body
    b2BodyId bodyIdA;

    /// The second attached body
    b2BodyId bodyIdB;

    /// The local anchor point relative to bodyA's origin
    b2Vec2 localAnchorA;

    /// The local anchor point relative to bodyB's origin
    b2Vec2 localAnchorB;

    /// The local translation unit axis in bodyA
    b2Vec2 localAxisA;

    /// Enable a linear spring along the local axis
    bool enableSpring;

    /// Spring stiffness in Hertz
    float hertz;

    /// Spring damping ratio, non-dimensional
    float dampingRatio;

    /// Enable/disable the joint linear limit
    bool enableLimit;

    /// The lower translation limit
    float lowerTranslation;

    /// The upper translation limit
    float upperTranslation;

    /// Enable/disable the joint rotational motor
    bool enableMotor;

    /// The maximum motor torque, typically in newton-meters
    float maxMotorTorque;

    /// The desired motor speed in radians per second
    float motorSpeed;

    /// Set this flag to true if the attached bodies should collide
    bool collideConnected;

    /// User data pointer
    void* userData;

    /// Used internally to detect a valid definition. DO NOT SET.
    int32_t internalValue;
} b2WheelJointDef;

/// Use this to initialize your joint definition
/// @ingroup wheel_joint
b2WheelJointDef b2DefaultWheelJointDef( void );

/**
 * @defgroup events Events
 * World event types.
 *
 * Events are used to collect events that occur during the world time step. These events
 * are then available to query after the time step is complete. This is preferable to callbacks
 * because Box2D uses multithreaded simulation.
 *
 * Also when events occur in the simulation step it may be problematic to modify the world, which is
 * often what applications want to do when events occur.
 *
 * With event arrays, you can scan the events in a loop and modify the world. However, you need to be careful
 * that some event data may become invalid. There are several samples that show how to do this safely.
 *
 * @{
 */

/// A begin touch event is generated when a shape starts to overlap a sensor shape.
typedef struct b2SensorBeginTouchEvent
{
    /// The id of the sensor shape
    b2ShapeId sensorShapeId;

    /// The id of the dynamic shape that began touching the sensor shape
    b2ShapeId visitorShapeId;
} b2SensorBeginTouchEvent;

/// An end touch event is generated when a shape stops overlapping a sensor shape.
typedef struct b2SensorEndTouchEvent
{
    /// The id of the sensor shape
    b2ShapeId sensorShapeId;

    /// The id of the dynamic shape that stopped touching the sensor shape
    b2ShapeId visitorShapeId;
} b2SensorEndTouchEvent;

/// Sensor events are buffered in the Box2D world and are available
///	as begin/end overlap event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
typedef struct b2SensorEvents
{
    /// Array of sensor begin touch events
    b2SensorBeginTouchEvent* beginEvents;

    /// Array of sensor end touch events
    b2SensorEndTouchEvent* endEvents;

    /// The number of begin touch events
    int32_t beginCount;

    /// The number of end touch events
    int32_t endCount;
} b2SensorEvents;

/// A begin touch event is generated when two shapes begin touching.
typedef struct b2ContactBeginTouchEvent
{
    /// Id of the first shape
    b2ShapeId shapeIdA;

    /// Id of the second shape
    b2ShapeId shapeIdB;
} b2ContactBeginTouchEvent;

/// An end touch event is generated when two shapes stop touching.
typedef struct b2ContactEndTouchEvent
{
    /// Id of the first shape
    b2ShapeId shapeIdA;

    /// Id of the second shape
    b2ShapeId shapeIdB;
} b2ContactEndTouchEvent;

/// A hit touch event is generated when two shapes collide with a speed faster than the hit speed threshold.
typedef struct b2ContactHitEvent
{
    /// Id of the first shape
    b2ShapeId shapeIdA;

    /// Id of the second shape
    b2ShapeId shapeIdB;

    /// Point where the shapes hit
    b2Vec2 point;

    /// Normal vector pointing from shape A to shape B
    b2Vec2 normal;

    /// The speed the shapes are approaching. Always positive. Typically in meters per second.
    float approachSpeed;
} b2ContactHitEvent;

/// Contact events are buffered in the Box2D world and are available
///	as event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
typedef struct b2ContactEvents
{
    /// Array of begin touch events
    b2ContactBeginTouchEvent* beginEvents;

    /// Array of end touch events
    b2ContactEndTouchEvent* endEvents;

    /// Array of hit events
    b2ContactHitEvent* hitEvents;

    /// Number of begin touch events
    int32_t beginCount;

    /// Number of end touch events
    int32_t endCount;

    /// Number of hit events
    int32_t hitCount;
} b2ContactEvents;

/// Body move events triggered when a body moves.
/// Triggered when a body moves due to simulation. Not reported for bodies moved by the user.
/// This also has a flag to indicate that the body went to sleep so the application can also
/// sleep that actor/entity/object associated with the body.
/// On the other hand if the flag does not indicate the body went to sleep then the application
/// can treat the actor/entity/object associated with the body as awake.
///	This is an efficient way for an application to update game object transforms rather than
///	calling functions such as b2Body_GetTransform() because this data is delivered as a contiguous array
///	and it is only populated with bodies that have moved.
///	@note If sleeping is disabled all dynamic and kinematic bodies will trigger move events.
typedef struct b2BodyMoveEvent
{
    b2Transform transform;
    b2BodyId bodyId;
    void* userData;
    bool fellAsleep;
} b2BodyMoveEvent;

/// Body events are buffered in the Box2D world and are available
///	as event arrays after the time step is complete.
///	Note: this data becomes invalid if bodies are destroyed
typedef struct b2BodyEvents
{
    /// Array of move events
    b2BodyMoveEvent* moveEvents;

    /// Number of move events
    int32_t moveCount;
} b2BodyEvents;


/// Low level ray-cast input data
typedef struct b2RayCastInput
{
    /// Start point of the ray cast
    b2Vec2 origin;

    /// Translation of the ray cast
    b2Vec2 translation;

    /// The maximum fraction of the translation to consider, typically 1
    float maxFraction;
} b2RayCastInput;

/// Low level shape cast input in generic form. This allows casting an arbitrary point
///	cloud wrap with a radius. For example, a circle is a single point with a non-zero radius.
///	A capsule is two points with a non-zero radius. A box is four points with a zero radius.
typedef struct b2ShapeCastInput
{
    /// A point cloud to cast
    b2Vec2 points[8];

    /// The number of points
    int32_t count;

    /// The radius around the point cloud
    float radius;

    /// The translation of the shape cast
    b2Vec2 translation;

    /// The maximum fraction of the translation to consider, typically 1
    float maxFraction;
} b2ShapeCastInput;

/// Low level ray-cast or shape-cast output data
typedef struct b2CastOutput
{
    /// The surface normal at the hit point
    b2Vec2 normal;

    /// The surface hit point
    b2Vec2 point;

    /// The fraction of the input translation at collision
    float fraction;

    /// The number of iterations used
    int32_t iterations;

    /// Did the cast hit?
    bool hit;
} b2CastOutput;

/// This holds the mass data computed for a shape.
typedef struct b2MassData
{
    /// The mass of the shape, usually in kilograms.
    float mass;

    /// The position of the shape's centroid relative to the shape's origin.
    b2Vec2 center;

    /// The rotational inertia of the shape about the local origin.
    float rotationalInertia;
} b2MassData;

/// A solid circle
typedef struct b2Circle
{
    /// The local center
    b2Vec2 center;

    /// The radius
    float radius;
} b2Circle;

/// A solid capsule can be viewed as two semicircles connected
///	by a rectangle.
typedef struct b2Capsule
{
    /// Local center of the first semicircle
    b2Vec2 center1;

    /// Local center of the second semicircle
    b2Vec2 center2;

    /// The radius of the semicircles
    float radius;
} b2Capsule;

/// A solid convex polygon. It is assumed that the interior of the polygon is to
/// the left of each edge.
/// Polygons have a maximum number of vertices equal to 8.
/// In most cases you should not need many vertices for a convex polygon.
///	@warning DO NOT fill this out manually, instead use a helper function like
///	b2MakePolygon or b2MakeBox.
typedef struct b2Polygon
{
    /// The polygon vertices
    b2Vec2 vertices[8];

    /// The outward normal vectors of the polygon sides
    b2Vec2 normals[8];

    /// The centroid of the polygon
    b2Vec2 centroid;

    /// The external radius for rounded polygons
    float radius;

    /// The number of polygon vertices
    int32_t count;
} b2Polygon;

/// A line segment with two-sided collision.
typedef struct b2Segment
{
    /// The first point
    b2Vec2 point1;

    /// The second point
    b2Vec2 point2;
} b2Segment;

/// A line segment with one-sided collision. Only collides on the right side.
/// Several of these are generated for a chain shape.
/// ghost1 -> point1 -> point2 -> ghost2
typedef struct b2ChainSegment
{
    /// The tail ghost vertex
    b2Vec2 ghost1;

    /// The line segment
    b2Segment segment;

    /// The head ghost vertex
    b2Vec2 ghost2;

    /// The owning chain shape index (internal usage only)
    int32_t chainId;
} b2ChainSegment;

/// Validate ray cast input data (NaN, etc)
bool b2IsValidRay( const b2RayCastInput* input );

/// A convex hull. Used to create convex polygons.
///	@warning Do not modify these values directly, instead use b2ComputeHull()
typedef struct b2Hull
{
    /// The final points of the hull
    b2Vec2 points[8];

    /// The number of points
    int32_t count;
} b2Hull;

/// Make a convex polygon from a convex hull. This will assert if the hull is not valid.
/// @warning Do not manually fill in the hull data, it must come directly from b2ComputeHull
b2Polygon b2MakePolygon( const b2Hull* hull, float radius );

/// Make an offset convex polygon from a convex hull. This will assert if the hull is not valid.
/// @warning Do not manually fill in the hull data, it must come directly from b2ComputeHull
b2Polygon b2MakeOffsetPolygon( const b2Hull* hull, float radius, b2Transform transform );

/// Make a square polygon, bypassing the need for a convex hull.
b2Polygon b2MakeSquare( float h );

/// Make a box (rectangle) polygon, bypassing the need for a convex hull.
b2Polygon b2MakeBox( float hx, float hy );

/// Make a rounded box, bypassing the need for a convex hull.
b2Polygon b2MakeRoundedBox( float hx, float hy, float radius );

/// Make an offset box, bypassing the need for a convex hull.
b2Polygon b2MakeOffsetBox( float hx, float hy, b2Vec2 center, b2Rot rotation );

/// Transform a polygon. This is useful for transferring a shape from one body to another.
b2Polygon b2TransformPolygon( b2Transform transform, const b2Polygon* polygon );

/// Compute mass properties of a circle
b2MassData b2ComputeCircleMass( const b2Circle* shape, float density );

/// Compute mass properties of a capsule
b2MassData b2ComputeCapsuleMass( const b2Capsule* shape, float density );

/// Compute mass properties of a polygon
b2MassData b2ComputePolygonMass( const b2Polygon* shape, float density );

/// Compute the bounding box of a transformed circle
b2AABB b2ComputeCircleAABB( const b2Circle* shape, b2Transform transform );

/// Compute the bounding box of a transformed capsule
b2AABB b2ComputeCapsuleAABB( const b2Capsule* shape, b2Transform transform );

/// Compute the bounding box of a transformed polygon
b2AABB b2ComputePolygonAABB( const b2Polygon* shape, b2Transform transform );

/// Compute the bounding box of a transformed line segment
b2AABB b2ComputeSegmentAABB( const b2Segment* shape, b2Transform transform );

/// Test a point for overlap with a circle in local space
bool b2PointInCircle( b2Vec2 point, const b2Circle* shape );

/// Test a point for overlap with a capsule in local space
bool b2PointInCapsule( b2Vec2 point, const b2Capsule* shape );

/// Test a point for overlap with a convex polygon in local space
bool b2PointInPolygon( b2Vec2 point, const b2Polygon* shape );

/// Ray cast versus circle in shape local space. Initial overlap is treated as a miss.
b2CastOutput b2RayCastCircle( const b2RayCastInput* input, const b2Circle* shape );

/// Ray cast versus capsule in shape local space. Initial overlap is treated as a miss.
b2CastOutput b2RayCastCapsule( const b2RayCastInput* input, const b2Capsule* shape );

/// Ray cast versus segment in shape local space. Optionally treat the segment as one-sided with hits from
/// the left side being treated as a miss.
b2CastOutput b2RayCastSegment( const b2RayCastInput* input, const b2Segment* shape, bool oneSided );

/// Ray cast versus polygon in shape local space. Initial overlap is treated as a miss.
b2CastOutput b2RayCastPolygon( const b2RayCastInput* input, const b2Polygon* shape );

/// Shape cast versus a circle. Initial overlap is treated as a miss.
b2CastOutput b2ShapeCastCircle( const b2ShapeCastInput* input, const b2Circle* shape );

/// Shape cast versus a capsule. Initial overlap is treated as a miss.
b2CastOutput b2ShapeCastCapsule( const b2ShapeCastInput* input, const b2Capsule* shape );

/// Shape cast versus a line segment. Initial overlap is treated as a miss.
b2CastOutput b2ShapeCastSegment( const b2ShapeCastInput* input, const b2Segment* shape );

/// Shape cast versus a convex polygon. Initial overlap is treated as a miss.
b2CastOutput b2ShapeCastPolygon( const b2ShapeCastInput* input, const b2Polygon* shape );

/// Compute the convex hull of a set of points. Returns an empty hull if it fails.
/// Some failure cases:
/// - all points very close together
/// - all points on a line
/// - less than 3 points
/// - more than 8 points
/// This welds close points and removes collinear points.
///	@warning Do not modify a hull once it has been computed
b2Hull b2ComputeHull( const b2Vec2* points, int32_t count );

/// This determines if a hull is valid. Checks for:
/// - convexity
/// - collinear points
/// This is expensive and should not be called at runtime.
bool b2ValidateHull( const b2Hull* hull );

/**@}*/

/**
 * @defgroup distance Distance
 * Functions for computing the distance between shapes.
 *
 * These are advanced functions you can use to perform distance calculations. There
 * are functions for computing the closest points between shapes, doing linear shape casts,
 * and doing rotational shape casts. The latter is called time of impact (TOI).
 * @{
 */

/// Result of computing the distance between two line segments
typedef struct b2SegmentDistanceResult
{
    /// The closest point on the first segment
    b2Vec2 closest1;

    /// The closest point on the second segment
    b2Vec2 closest2;

    /// The barycentric coordinate on the first segment
    float fraction1;

    /// The barycentric coordinate on the second segment
    float fraction2;

    /// The squared distance between the closest points
    float distanceSquared;
} b2SegmentDistanceResult;

/// Compute the distance between two line segments, clamping at the end points if needed.
b2SegmentDistanceResult b2SegmentDistance( b2Vec2 p1, b2Vec2 q1, b2Vec2 p2, b2Vec2 q2 );

/// A distance proxy is used by the GJK algorithm. It encapsulates any shape.
typedef struct b2DistanceProxy
{
    /// The point cloud
    b2Vec2 points[8];

    /// The number of points
    int32_t count;

    /// The external radius of the point cloud
    float radius;
} b2DistanceProxy;

/// Used to warm start b2Distance. Set count to zero on first call or
///	use zero initialization.
typedef struct b2DistanceCache
{
    /// The number of stored simplex points
    uint16_t count;

    /// The cached simplex indices on shape A
    uint8_t indexA[3];

    /// The cached simplex indices on shape B
    uint8_t indexB[3];
} b2DistanceCache;

/// Input for b2ShapeDistance
typedef struct b2DistanceInput
{
    /// The proxy for shape A
    b2DistanceProxy proxyA;

    /// The proxy for shape B
    b2DistanceProxy proxyB;

    /// The world transform for shape A
    b2Transform transformA;

    /// The world transform for shape B
    b2Transform transformB;

    /// Should the proxy radius be considered?
    bool useRadii;
} b2DistanceInput;

/// Output for b2ShapeDistance
typedef struct b2DistanceOutput
{
    b2Vec2 pointA;		  ///< Closest point on shapeA
    b2Vec2 pointB;		  ///< Closest point on shapeB
    float distance;		  ///< The final distance, zero if overlapped
    int32_t iterations;	  ///< Number of GJK iterations used
    int32_t simplexCount; ///< The number of simplexes stored in the simplex array
} b2DistanceOutput;

/// Simplex vertex for debugging the GJK algorithm
typedef struct b2SimplexVertex
{
    b2Vec2 wA;		///< support point in proxyA
    b2Vec2 wB;		///< support point in proxyB
    b2Vec2 w;		///< wB - wA
    float a;		///< barycentric coordinate for closest point
    int32_t indexA; ///< wA index
    int32_t indexB; ///< wB index
} b2SimplexVertex;

/// Simplex from the GJK algorithm
typedef struct b2Simplex
{
    b2SimplexVertex v1, v2, v3; ///< vertices
    int32_t count;				///< number of valid vertices
} b2Simplex;

/// Compute the closest points between two shapes represented as point clouds.
/// b2DistanceCache cache is input/output. On the first call set b2DistanceCache.count to zero.
///	The underlying GJK algorithm may be debugged by passing in debug simplexes and capacity. You may pass in NULL and 0 for these.
b2DistanceOutput b2ShapeDistance( b2DistanceCache* cache, const b2DistanceInput* input, b2Simplex* simplexes,
int simplexCapacity );

/// Input parameters for b2ShapeCast
typedef struct b2ShapeCastPairInput
{
    b2DistanceProxy proxyA; ///< The proxy for shape A
    b2DistanceProxy proxyB; ///< The proxy for shape B
    b2Transform transformA; ///< The world transform for shape A
    b2Transform transformB; ///< The world transform for shape B
    b2Vec2 translationB;	///< The translation of shape B
    float maxFraction;		///< The fraction of the translation to consider, typically 1
} b2ShapeCastPairInput;

/// Perform a linear shape cast of shape B moving and shape A fixed. Determines the hit point, normal, and translation fraction.
b2CastOutput b2ShapeCast( const b2ShapeCastPairInput* input );

/// Make a proxy for use in GJK and related functions.
b2DistanceProxy b2MakeProxy( const b2Vec2* vertices, int32_t count, float radius );

/// This describes the motion of a body/shape for TOI computation. Shapes are defined with respect to the body origin,
/// which may not coincide with the center of mass. However, to support dynamics we must interpolate the center of mass
/// position.
typedef struct b2Sweep
{
    b2Vec2 localCenter; ///< Local center of mass position
    b2Vec2 c1;			///< Starting center of mass world position
    b2Vec2 c2;			///< Ending center of mass world position
    b2Rot q1;			///< Starting world rotation
    b2Rot q2;			///< Ending world rotation
} b2Sweep;

/// Evaluate the transform sweep at a specific time.
b2Transform b2GetSweepTransform( const b2Sweep* sweep, float time );

/// Input parameters for b2TimeOfImpact
typedef struct b2TOIInput
{
    b2DistanceProxy proxyA; ///< The proxy for shape A
    b2DistanceProxy proxyB; ///< The proxy for shape B
    b2Sweep sweepA;			///< The movement of shape A
    b2Sweep sweepB;			///< The movement of shape B
    float tMax;				///< Defines the sweep interval [0, tMax]
} b2TOIInput;

/// Describes the TOI output
typedef enum b2TOIState
{
    b2_toiStateUnknown,
    b2_toiStateFailed,
    b2_toiStateOverlapped,
    b2_toiStateHit,
    b2_toiStateSeparated
} b2TOIState;

/// Output parameters for b2TimeOfImpact.
typedef struct b2TOIOutput
{
    b2TOIState state; ///< The type of result
    float t;		  ///< The time of the collision
} b2TOIOutput;

/// Compute the upper bound on time before two shapes penetrate. Time is represented as
/// a fraction between [0,tMax]. This uses a swept separating axis and may miss some intermediate,
/// non-tunneling collisions. If you change the time interval, you should call this function
/// again.
b2TOIOutput b2TimeOfImpact( const b2TOIInput* input );

/**@}*/

/**
 * @defgroup collision Collision
 * @brief Functions for colliding pairs of shapes
 * @{
 */

/// A manifold point is a contact point belonging to a contact
/// manifold. It holds details related to the geometry and dynamics
/// of the contact points.
typedef struct b2ManifoldPoint
{
    /// Location of the contact point in world space. Subject to precision loss at large coordinates.
    ///	@note Should only be used for debugging.
    b2Vec2 point;

    /// Location of the contact point relative to bodyA's origin in world space
    ///	@note When used internally to the Box2D solver, these are relative to the center of mass.
    b2Vec2 anchorA;

    /// Location of the contact point relative to bodyB's origin in world space
    b2Vec2 anchorB;

    /// The separation of the contact point, negative if penetrating
    float separation;

    /// The impulse along the manifold normal vector.
    float normalImpulse;

    /// The friction impulse
    float tangentImpulse;

    /// The maximum normal impulse applied during sub-stepping
    ///	todo not sure this is needed
    float maxNormalImpulse;

    /// Relative normal velocity pre-solve. Used for hit events. If the normal impulse is
    /// zero then there was no hit. Negative means shapes are approaching.
    float normalVelocity;

    /// Uniquely identifies a contact point between two shapes
    uint16_t id;

    /// Did this contact point exist the previous step?
    bool persisted;
} b2ManifoldPoint;

/// A contact manifold describes the contact points between colliding shapes
typedef struct b2Manifold
{
    /// The manifold points, up to two are possible in 2D
    b2ManifoldPoint points[2];

    /// The unit normal vector in world space, points from shape A to bodyB
    b2Vec2 normal;

    /// The number of contacts points, will be 0, 1, or 2
    int32_t pointCount;
} b2Manifold;

/// Compute the contact manifold between two circles
b2Manifold b2CollideCircles( const b2Circle* circleA, b2Transform xfA, const b2Circle* circleB, b2Transform xfB );

/// Compute the contact manifold between a capsule and circle
b2Manifold b2CollideCapsuleAndCircle( const b2Capsule* capsuleA, b2Transform xfA, const b2Circle* circleB,
b2Transform xfB );

/// Compute the contact manifold between an segment and a circle
b2Manifold b2CollideSegmentAndCircle( const b2Segment* segmentA, b2Transform xfA, const b2Circle* circleB,
b2Transform xfB );

/// Compute the contact manifold between a polygon and a circle
b2Manifold b2CollidePolygonAndCircle( const b2Polygon* polygonA, b2Transform xfA, const b2Circle* circleB,
b2Transform xfB );

/// Compute the contact manifold between a capsule and circle
b2Manifold b2CollideCapsules( const b2Capsule* capsuleA, b2Transform xfA, const b2Capsule* capsuleB, b2Transform xfB );

/// Compute the contact manifold between an segment and a capsule
b2Manifold b2CollideSegmentAndCapsule( const b2Segment* segmentA, b2Transform xfA, const b2Capsule* capsuleB,
b2Transform xfB );

/// Compute the contact manifold between a polygon and capsule
b2Manifold b2CollidePolygonAndCapsule( const b2Polygon* polygonA, b2Transform xfA, const b2Capsule* capsuleB,
b2Transform xfB );

/// Compute the contact manifold between two polygons
b2Manifold b2CollidePolygons( const b2Polygon* polygonA, b2Transform xfA, const b2Polygon* polygonB, b2Transform xfB );

/// Compute the contact manifold between an segment and a polygon
b2Manifold b2CollideSegmentAndPolygon( const b2Segment* segmentA, b2Transform xfA, const b2Polygon* polygonB,
b2Transform xfB );

/// Compute the contact manifold between a chain segment and a circle
b2Manifold b2CollideChainSegmentAndCircle( const b2ChainSegment* segmentA, b2Transform xfA,
const b2Circle* circleB, b2Transform xfB );

/// Compute the contact manifold between a chain segment and a capsule
b2Manifold b2CollideChainSegmentAndCapsule( const b2ChainSegment* segmentA, b2Transform xfA,
const b2Capsule* capsuleB, b2Transform xfB, b2DistanceCache* cache );

/// Compute the contact manifold between a chain segment and a rounded polygon
b2Manifold b2CollideChainSegmentAndPolygon( const b2ChainSegment* segmentA, b2Transform xfA,
const b2Polygon* polygonB, b2Transform xfB, b2DistanceCache* cache );

/// The contact data for two shapes. By convention the manifold normal points
///	from shape A to shape B.
///	@see b2Shape_GetContactData() and b2Body_GetContactData()
typedef struct b2ContactData
{
    b2ShapeId shapeIdA;
    b2ShapeId shapeIdB;
    b2Manifold manifold;
} b2ContactData;

/**@}*/

/// Prototype for a contact filter callback.
/// This is called when a contact pair is considered for collision. This allows you to
///	perform custom logic to prevent collision between shapes. This is only called if
///	one of the two shapes has custom filtering enabled. @see b2ShapeDef.
/// Notes:
///	- this function must be thread-safe
///	- this is only called if one of the two shapes has enabled custom filtering
/// - this is called only for awake dynamic bodies
///	Return false if you want to disable the collision
///	@warning Do not attempt to modify the world inside this callback
///	@ingroup world
typedef bool b2CustomFilterFcn( b2ShapeId shapeIdA, b2ShapeId shapeIdB, void* context );

/// Prototype for a pre-solve callback.
/// This is called after a contact is updated. This allows you to inspect a
/// contact before it goes to the solver. If you are careful, you can modify the
/// contact manifold (e.g. modify the normal).
/// Notes:
///	- this function must be thread-safe
///	- this is only called if the shape has enabled pre-solve events
/// - this is called only for awake dynamic bodies
/// - this is not called for sensors
/// - the supplied manifold has impulse values from the previous step
///	Return false if you want to disable the contact this step
///	@warning Do not attempt to modify the world inside this callback
///	@ingroup world
typedef bool b2PreSolveFcn( b2ShapeId shapeIdA, b2ShapeId shapeIdB, b2Manifold* manifold, void* context );

/// Prototype callback for overlap queries.
/// Called for each shape found in the query.
/// @see b2World_QueryAABB
/// @return false to terminate the query.
///	@ingroup world
typedef bool b2OverlapResultFcn( b2ShapeId shapeId, void* context );

/// Prototype callback for ray casts.
/// Called for each shape found in the query. You control how the ray cast
/// proceeds by returning a float:
/// return -1: ignore this shape and continue
/// return 0: terminate the ray cast
/// return fraction: clip the ray to this point
/// return 1: don't clip the ray and continue
/// @param shapeId the shape hit by the ray
/// @param point the point of initial intersection
/// @param normal the normal vector at the point of intersection
/// @param fraction the fraction along the ray at the point of intersection
///	@param context the user context
/// @return -1 to filter, 0 to terminate, fraction to clip the ray for closest hit, 1 to continue
/// @see b2World_CastRay
///	@ingroup world
typedef float b2CastResultFcn( b2ShapeId shapeId, b2Vec2 point, b2Vec2 normal, float fraction, void* context );

/// These colors are used for debug draw.
///	See https://www.rapidtables.com/web/color/index.html
typedef enum b2HexColor
{
    b2_colorAliceBlue = 0xf0f8ff,
    b2_colorAntiqueWhite = 0xfaebd7,
    b2_colorAquamarine = 0x7fffd4,
    b2_colorAzure = 0xf0ffff,
    b2_colorBeige = 0xf5f5dc,
    b2_colorBisque = 0xffe4c4,
    b2_colorBlack = 0x000000,
    b2_colorBlanchedAlmond = 0xffebcd,
    b2_colorBlue = 0x0000ff,
    b2_colorBlueViolet = 0x8a2be2,
    b2_colorBrown = 0xa52a2a,
    b2_colorBurlywood = 0xdeb887,
    b2_colorCadetBlue = 0x5f9ea0,
    b2_colorChartreuse = 0x7fff00,
    b2_colorChocolate = 0xd2691e,
    b2_colorCoral = 0xff7f50,
    b2_colorCornflowerBlue = 0x6495ed,
    b2_colorCornsilk = 0xfff8dc,
    b2_colorCrimson = 0xdc143c,
    b2_colorCyan = 0x00ffff,
    b2_colorDarkBlue = 0x00008b,
    b2_colorDarkCyan = 0x008b8b,
    b2_colorDarkGoldenrod = 0xb8860b,
    b2_colorDarkGray = 0xa9a9a9,
    b2_colorDarkGreen = 0x006400,
    b2_colorDarkKhaki = 0xbdb76b,
    b2_colorDarkMagenta = 0x8b008b,
    b2_colorDarkOliveGreen = 0x556b2f,
    b2_colorDarkOrange = 0xff8c00,
    b2_colorDarkOrchid = 0x9932cc,
    b2_colorDarkRed = 0x8b0000,
    b2_colorDarkSalmon = 0xe9967a,
    b2_colorDarkSeaGreen = 0x8fbc8f,
    b2_colorDarkSlateBlue = 0x483d8b,
    b2_colorDarkSlateGray = 0x2f4f4f,
    b2_colorDarkTurquoise = 0x00ced1,
    b2_colorDarkViolet = 0x9400d3,
    b2_colorDeepPink = 0xff1493,
    b2_colorDeepSkyBlue = 0x00bfff,
    b2_colorDimGray = 0x696969,
    b2_colorDodgerBlue = 0x1e90ff,
    b2_colorFirebrick = 0xb22222,
    b2_colorFloralWhite = 0xfffaf0,
    b2_colorForestGreen = 0x228b22,
    b2_colorGainsboro = 0xdcdcdc,
    b2_colorGhostWhite = 0xf8f8ff,
    b2_colorGold = 0xffd700,
    b2_colorGoldenrod = 0xdaa520,
    b2_colorGray = 0xbebebe,
    b2_colorGray1 = 0x1a1a1a,
    b2_colorGray2 = 0x333333,
    b2_colorGray3 = 0x4d4d4d,
    b2_colorGray4 = 0x666666,
    b2_colorGray5 = 0x7f7f7f,
    b2_colorGray6 = 0x999999,
    b2_colorGray7 = 0xb3b3b3,
    b2_colorGray8 = 0xcccccc,
    b2_colorGray9 = 0xe5e5e5,
    b2_colorGreen = 0x00ff00,
    b2_colorGreenYellow = 0xadff2f,
    b2_colorHoneydew = 0xf0fff0,
    b2_colorHotPink = 0xff69b4,
    b2_colorIndianRed = 0xcd5c5c,
    b2_colorIndigo = 0x4b0082,
    b2_colorIvory = 0xfffff0,
    b2_colorKhaki = 0xf0e68c,
    b2_colorLavender = 0xe6e6fa,
    b2_colorLavenderBlush = 0xfff0f5,
    b2_colorLawnGreen = 0x7cfc00,
    b2_colorLemonChiffon = 0xfffacd,
    b2_colorLightBlue = 0xadd8e6,
    b2_colorLightCoral = 0xf08080,
    b2_colorLightCyan = 0xe0ffff,
    b2_colorLightGoldenrod = 0xeedd82,
    b2_colorLightGoldenrodYellow = 0xfafad2,
    b2_colorLightGray = 0xd3d3d3,
    b2_colorLightGreen = 0x90ee90,
    b2_colorLightPink = 0xffb6c1,
    b2_colorLightSalmon = 0xffa07a,
    b2_colorLightSeaGreen = 0x20b2aa,
    b2_colorLightSkyBlue = 0x87cefa,
    b2_colorLightSlateBlue = 0x8470ff,
    b2_colorLightSlateGray = 0x778899,
    b2_colorLightSteelBlue = 0xb0c4de,
    b2_colorLightYellow = 0xffffe0,
    b2_colorLimeGreen = 0x32cd32,
    b2_colorLinen = 0xfaf0e6,
    b2_colorMagenta = 0xff00ff,
    b2_colorMaroon = 0xb03060,
    b2_colorMediumAquamarine = 0x66cdaa,
    b2_colorMediumBlue = 0x0000cd,
    b2_colorMediumOrchid = 0xba55d3,
    b2_colorMediumPurple = 0x9370db,
    b2_colorMediumSeaGreen = 0x3cb371,
    b2_colorMediumSlateBlue = 0x7b68ee,
    b2_colorMediumSpringGreen = 0x00fa9a,
    b2_colorMediumTurquoise = 0x48d1cc,
    b2_colorMediumVioletRed = 0xc71585,
    b2_colorMidnightBlue = 0x191970,
    b2_colorMintCream = 0xf5fffa,
    b2_colorMistyRose = 0xffe4e1,
    b2_colorMoccasin = 0xffe4b5,
    b2_colorNavajoWhite = 0xffdead,
    b2_colorNavyBlue = 0x000080,
    b2_colorOldLace = 0xfdf5e6,
    b2_colorOlive = 0x808000,
    b2_colorOliveDrab = 0x6b8e23,
    b2_colorOrange = 0xffa500,
    b2_colorOrangeRed = 0xff4500,
    b2_colorOrchid = 0xda70d6,
    b2_colorPaleGoldenrod = 0xeee8aa,
    b2_colorPaleGreen = 0x98fb98,
    b2_colorPaleTurquoise = 0xafeeee,
    b2_colorPaleVioletRed = 0xdb7093,
    b2_colorPapayaWhip = 0xffefd5,
    b2_colorPeachPuff = 0xffdab9,
    b2_colorPeru = 0xcd853f,
    b2_colorPink = 0xffc0cb,
    b2_colorPlum = 0xdda0dd,
    b2_colorPowderBlue = 0xb0e0e6,
    b2_colorPurple = 0xa020f0,
    b2_colorRebeccaPurple = 0x663399,
    b2_colorRed = 0xff0000,
    b2_colorRosyBrown = 0xbc8f8f,
    b2_colorRoyalBlue = 0x4169e1,
    b2_colorSaddleBrown = 0x8b4513,
    b2_colorSalmon = 0xfa8072,
    b2_colorSandyBrown = 0xf4a460,
    b2_colorSeaGreen = 0x2e8b57,
    b2_colorSeashell = 0xfff5ee,
    b2_colorSienna = 0xa0522d,
    b2_colorSilver = 0xc0c0c0,
    b2_colorSkyBlue = 0x87ceeb,
    b2_colorSlateBlue = 0x6a5acd,
    b2_colorSlateGray = 0x708090,
    b2_colorSnow = 0xfffafa,
    b2_colorSpringGreen = 0x00ff7f,
    b2_colorSteelBlue = 0x4682b4,
    b2_colorTan = 0xd2b48c,
    b2_colorTeal = 0x008080,
    b2_colorThistle = 0xd8bfd8,
    b2_colorTomato = 0xff6347,
    b2_colorTurquoise = 0x40e0d0,
    b2_colorViolet = 0xee82ee,
    b2_colorVioletRed = 0xd02090,
    b2_colorWheat = 0xf5deb3,
    b2_colorWhite = 0xffffff,
    b2_colorWhiteSmoke = 0xf5f5f5,
    b2_colorYellow = 0xffff00,
    b2_colorYellowGreen = 0x9acd32,
    b2_colorBox2DRed = 0xdc3132,
    b2_colorBox2DBlue = 0x30aebf,
    b2_colorBox2DGreen = 0x8cc924,
    b2_colorBox2DYellow = 0xffee8c
} b2HexColor;

/// This struct holds callbacks you can implement to draw a Box2D world.
///	This structure should be zero initialized.
///	@ingroup world
typedef struct b2DebugDraw
{
    /// Draw a closed polygon provided in CCW order.
    void ( *DrawPolygon )( const b2Vec2* vertices, int vertexCount, b2HexColor color, void* context );

    /// Draw a solid closed polygon provided in CCW order.
    void ( *DrawSolidPolygon )( b2Transform transform, const b2Vec2* vertices, int vertexCount, float radius, b2HexColor color,
    void* context );

    /// Draw a circle.
    void ( *DrawCircle )( b2Vec2 center, float radius, b2HexColor color, void* context );

    /// Draw a solid circle.
    void ( *DrawSolidCircle )( b2Transform transform, float radius, b2HexColor color, void* context );

    /// Draw a solid capsule.
    void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );

    /// Draw a line segment.
    void ( *DrawSegment )( b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context );

    /// Draw a transform. Choose your own length scale.
    void ( *DrawTransform )( b2Transform transform, void* context );

    /// Draw a point.
    void ( *DrawPoint )( b2Vec2 p, float size, b2HexColor color, void* context );

    /// Draw a string.
    void ( *DrawString )( b2Vec2 p, const char* s, void* context );

    /// Bounds to use if restricting drawing to a rectangular region
    b2AABB drawingBounds;

    /// Option to restrict drawing to a rectangular region. May suffer from unstable depth sorting.
    bool useDrawingBounds;

    /// Option to draw shapes
    bool drawShapes;

    /// Option to draw joints
    bool drawJoints;

    /// Option to draw additional information for joints
    bool drawJointExtras;

    /// Option to draw the bounding boxes for shapes
    bool drawAABBs;

    /// Option to draw the mass and center of mass of dynamic bodies
    bool drawMass;

    /// Option to draw contact points
    bool drawContacts;

    /// Option to visualize the graph coloring used for contacts and joints
    bool drawGraphColors;

    /// Option to draw contact normals
    bool drawContactNormals;

    /// Option to draw contact normal impulses
    bool drawContactImpulses;

    /// Option to draw contact friction impulses
    bool drawFrictionImpulses;

    /// User context that is passed as an argument to drawing callback functions
    void* context;
} b2DebugDraw;

/// Use this to initialize your drawing interface. This allows you to implement a sub-set
/// of the drawing functions.
b2DebugDraw b2DefaultDebugDraw( void );

/// Create a world for rigid body simulation. A world contains bodies, shapes, and constraints. You make create
///	up to 128 worlds. Each world is completely independent and may be simulated in parallel.
///	@return the world id.
b2WorldId b2CreateWorld( const b2WorldDef* def );

/// Destroy a world
void b2DestroyWorld( b2WorldId worldId );

/// World id validation. Provides validation for up to 64K allocations.
bool b2World_IsValid( b2WorldId id );

/// Simulate a world for one time step. This performs collision detection, integration, and constraint solution.
/// @param worldId The world to simulate
/// @param timeStep The amount of time to simulate, this should be a fixed number. Typically 1/60.
/// @param subStepCount The number of sub-steps, increasing the sub-step count can increase accuracy. Typically 4.
void b2World_Step( b2WorldId worldId, float timeStep, int subStepCount );

/// Call this to draw shapes and other debug draw data
void b2World_Draw( b2WorldId worldId, b2DebugDraw* draw );

/// Get the body events for the current time step. The event data is transient. Do not store a reference to this data.
b2BodyEvents b2World_GetBodyEvents( b2WorldId worldId );

/// Get sensor events for the current time step. The event data is transient. Do not store a reference to this data.
b2SensorEvents b2World_GetSensorEvents( b2WorldId worldId );

/// Get contact events for this current time step. The event data is transient. Do not store a reference to this data.
b2ContactEvents b2World_GetContactEvents( b2WorldId worldId );

/// Overlap test for all shapes that *potentially* overlap the provided AABB
void b2World_OverlapAABB( b2WorldId worldId, b2AABB aabb, b2QueryFilter filter, b2OverlapResultFcn* fcn, void* context );

/// Overlap test for for all shapes that overlap the provided circle
void b2World_OverlapCircle( b2WorldId worldId, const b2Circle* circle, b2Transform transform, b2QueryFilter filter,
b2OverlapResultFcn* fcn, void* context );

/// Overlap test for all shapes that overlap the provided capsule
void b2World_OverlapCapsule( b2WorldId worldId, const b2Capsule* capsule, b2Transform transform, b2QueryFilter filter,
b2OverlapResultFcn* fcn, void* context );

/// Overlap test for all shapes that overlap the provided polygon
void b2World_OverlapPolygon( b2WorldId worldId, const b2Polygon* polygon, b2Transform transform, b2QueryFilter filter,
b2OverlapResultFcn* fcn, void* context );

/// Cast a ray into the world to collect shapes in the path of the ray.
/// Your callback function controls whether you get the closest point, any point, or n-points.
/// The ray-cast ignores shapes that contain the starting point.
///	@param worldId The world to cast the ray against
///	@param origin The start point of the ray
///	@param translation The translation of the ray from the start point to the end point
///	@param filter Contains bit flags to filter unwanted shapes from the results
/// @param fcn A user implemented callback function
/// @param context A user context that is passed along to the callback function
///	@note The callback function may receive shapes in any order
void b2World_CastRay( b2WorldId worldId, b2Vec2 origin, b2Vec2 translation, b2QueryFilter filter, b2CastResultFcn* fcn,
void* context );

/// Cast a ray into the world to collect the closest hit. This is a convenience function.
/// This is less general than b2World_CastRay() and does not allow for custom filtering.
b2RayResult b2World_CastRayClosest( b2WorldId worldId, b2Vec2 origin, b2Vec2 translation, b2QueryFilter filter );

/// Cast a circle through the world. Similar to a cast ray except that a circle is cast instead of a point.
void b2World_CastCircle( b2WorldId worldId, const b2Circle* circle, b2Transform originTransform, b2Vec2 translation,
b2QueryFilter filter, b2CastResultFcn* fcn, void* context );

/// Cast a capsule through the world. Similar to a cast ray except that a capsule is cast instead of a point.
void b2World_CastCapsule( b2WorldId worldId, const b2Capsule* capsule, b2Transform originTransform, b2Vec2 translation,
b2QueryFilter filter, b2CastResultFcn* fcn, void* context );

/// Cast a polygon through the world. Similar to a cast ray except that a polygon is cast instead of a point.
void b2World_CastPolygon( b2WorldId worldId, const b2Polygon* polygon, b2Transform originTransform, b2Vec2 translation,
b2QueryFilter filter, b2CastResultFcn* fcn, void* context );

/// Enable/disable sleep. If your application does not need sleeping, you can gain some performance
///	by disabling sleep completely at the world level.
///	@see b2WorldDef
void b2World_EnableSleeping( b2WorldId worldId, bool flag );

/// Is body sleeping enabled?
bool b2World_IsSleepingEnabled( b2WorldId worldId );

/// Enable/disable continuous collision between dynamic and static bodies. Generally you should keep continuous
/// collision enabled to prevent fast moving objects from going through static objects. The performance gain from
///	disabling continuous collision is minor.
///	@see b2WorldDef
void b2World_EnableContinuous( b2WorldId worldId, bool flag );

/// Is continuous collision enabled?
bool b2World_IsContinuousEnabled( b2WorldId worldId );

/// Adjust the restitution threshold. It is recommended not to make this value very small
///	because it will prevent bodies from sleeping. Typically in meters per second.
///	@see b2WorldDef
void b2World_SetRestitutionThreshold( b2WorldId worldId, float value );

/// Get the the restitution speed threshold. Typically in meters per second.
float b2World_GetRestitutionThreshold( b2WorldId worldId );

/// Adjust the hit event threshold. This controls the collision velocity needed to generate a b2ContactHitEvent.
/// Typically in meters per second.
///	@see b2WorldDef::hitEventThreshold
void b2World_SetHitEventThreshold( b2WorldId worldId, float value );

/// Get the the hit event speed threshold. Typically in meters per second.
float b2World_GetHitEventThreshold( b2WorldId worldId );

/// Register the custom filter callback. This is optional.
void b2World_SetCustomFilterCallback( b2WorldId worldId, b2CustomFilterFcn* fcn, void* context );

/// Register the pre-solve callback. This is optional.
void b2World_SetPreSolveCallback( b2WorldId worldId, b2PreSolveFcn* fcn, void* context );

/// Set the gravity vector for the entire world. Box2D has no concept of an up direction and this
/// is left as a decision for the application. Typically in m/s^2.
///	@see b2WorldDef
void b2World_SetGravity( b2WorldId worldId, b2Vec2 gravity );

/// Get the gravity vector
b2Vec2 b2World_GetGravity( b2WorldId worldId );

/// Apply a radial explosion
///	@param worldId The world id
///	@param position The center of the explosion
///	@param radius The radius of the explosion
///	@param impulse The impulse of the explosion, typically in kg * m / s or N * s.
void b2World_Explode( b2WorldId worldId, b2Vec2 position, float radius, float impulse );

/// Adjust contact tuning parameters
///	@param worldId The world id
/// @param hertz The contact stiffness (cycles per second)
/// @param dampingRatio The contact bounciness with 1 being critical damping (non-dimensional)
/// @param pushVelocity The maximum contact constraint push out velocity (meters per second)
///	@note Advanced feature
void b2World_SetContactTuning( b2WorldId worldId, float hertz, float dampingRatio, float pushVelocity );

/// Enable/disable constraint warm starting. Advanced feature for testing. Disabling
///	sleeping greatly reduces stability and provides no performance gain.
void b2World_EnableWarmStarting( b2WorldId worldId, bool flag );

/// Is constraint warm starting enabled?
bool b2World_IsWarmStartingEnabled( b2WorldId worldId );

/// Get the current world performance profile
b2Profile b2World_GetProfile( b2WorldId worldId );

/// Get world counters and sizes
b2Counters b2World_GetCounters( b2WorldId worldId );

/// Dump memory stats to box2d_memory.txt
void b2World_DumpMemoryStats( b2WorldId worldId );

/** @} */

/**
 * @defgroup body Body
 * This is the body API.
 * @{
 */

/// Create a rigid body given a definition. No reference to the definition is retained. So you can create the definition
///	on the stack and pass it as a pointer.
///	@code{.c}
///	b2BodyDef bodyDef = b2DefaultBodyDef();
///	b2BodyId myBodyId = b2CreateBody(myWorldId, &bodyDef);
///	@endcode
/// @warning This function is locked during callbacks.
b2BodyId b2CreateBody( b2WorldId worldId, const b2BodyDef* def );

/// Destroy a rigid body given an id. This destroys all shapes and joints attached to the body.
///	Do not keep references to the associated shapes and joints.
void b2DestroyBody( b2BodyId bodyId );

/// Body identifier validation. Can be used to detect orphaned ids. Provides validation for up to 64K allocations.
bool b2Body_IsValid( b2BodyId id );

/// Get the body type: static, kinematic, or dynamic
b2BodyType b2Body_GetType( b2BodyId bodyId );

/// Change the body type. This is an expensive operation. This automatically updates the mass
///	properties regardless of the automatic mass setting.
void b2Body_SetType( b2BodyId bodyId, b2BodyType type );

/// Set the user data for a body
void b2Body_SetUserData( b2BodyId bodyId, void* userData );

/// Get the user data stored in a body
void* b2Body_GetUserData( b2BodyId bodyId );

/// Get the world position of a body. This is the location of the body origin.
b2Vec2 b2Body_GetPosition( b2BodyId bodyId );

/// Get the world rotation of a body as a cosine/sine pair (complex number)
b2Rot b2Body_GetRotation( b2BodyId bodyId );

/// Get the world transform of a body.
b2Transform b2Body_GetTransform( b2BodyId bodyId );

/// Set the world transform of a body. This acts as a teleport and is fairly expensive.
/// @note Generally you should create a body with then intended transform.
///	@see b2BodyDef::position and b2BodyDef::angle
void b2Body_SetTransform( b2BodyId bodyId, b2Vec2 position, b2Rot rotation );

/// Get a local point on a body given a world point
b2Vec2 b2Body_GetLocalPoint( b2BodyId bodyId, b2Vec2 worldPoint );

/// Get a world point on a body given a local point
b2Vec2 b2Body_GetWorldPoint( b2BodyId bodyId, b2Vec2 localPoint );

/// Get a local vector on a body given a world vector
b2Vec2 b2Body_GetLocalVector( b2BodyId bodyId, b2Vec2 worldVector );

/// Get a world vector on a body given a local vector
b2Vec2 b2Body_GetWorldVector( b2BodyId bodyId, b2Vec2 localVector );

/// Get the linear velocity of a body's center of mass. Typically in meters per second.
b2Vec2 b2Body_GetLinearVelocity( b2BodyId bodyId );

/// Get the angular velocity of a body in radians per second
float b2Body_GetAngularVelocity( b2BodyId bodyId );

/// Set the linear velocity of a body. Typically in meters per second.
void b2Body_SetLinearVelocity( b2BodyId bodyId, b2Vec2 linearVelocity );

/// Set the angular velocity of a body in radians per second
void b2Body_SetAngularVelocity( b2BodyId bodyId, float angularVelocity );

/// Apply a force at a world point. If the force is not applied at the center of mass,
/// it will generate a torque and affect the angular velocity. This optionally wakes up the body.
///	The force is ignored if the body is not awake.
///	@param bodyId The body id
/// @param force The world force vector, typically in newtons (N)
/// @param point The world position of the point of application
/// @param wake Option to wake up the body
void b2Body_ApplyForce( b2BodyId bodyId, b2Vec2 force, b2Vec2 point, bool wake );

/// Apply a force to the center of mass. This optionally wakes up the body.
///	The force is ignored if the body is not awake.
///	@param bodyId The body id
/// @param force the world force vector, usually in newtons (N).
/// @param wake also wake up the body
void b2Body_ApplyForceToCenter( b2BodyId bodyId, b2Vec2 force, bool wake );

/// Apply a torque. This affects the angular velocity without affecting the linear velocity.
///	This optionally wakes the body. The torque is ignored if the body is not awake.
///	@param bodyId The body id
/// @param torque about the z-axis (out of the screen), typically in N*m.
/// @param wake also wake up the body
void b2Body_ApplyTorque( b2BodyId bodyId, float torque, bool wake );

/// Apply an impulse at a point. This immediately modifies the velocity.
/// It also modifies the angular velocity if the point of application
/// is not at the center of mass. This optionally wakes the body.
/// The impulse is ignored if the body is not awake.
///	@param bodyId The body id
/// @param impulse the world impulse vector, typically in N*s or kg*m/s.
/// @param point the world position of the point of application.
/// @param wake also wake up the body
///	@warning This should be used for one-shot impulses. If you need a steady force,
/// use a force instead, which will work better with the sub-stepping solver.
void b2Body_ApplyLinearImpulse( b2BodyId bodyId, b2Vec2 impulse, b2Vec2 point, bool wake );

/// Apply an impulse to the center of mass. This immediately modifies the velocity.
/// The impulse is ignored if the body is not awake. This optionally wakes the body.
///	@param bodyId The body id
/// @param impulse the world impulse vector, typically in N*s or kg*m/s.
/// @param wake also wake up the body
///	@warning This should be used for one-shot impulses. If you need a steady force,
/// use a force instead, which will work better with the sub-stepping solver.
void b2Body_ApplyLinearImpulseToCenter( b2BodyId bodyId, b2Vec2 impulse, bool wake );

/// Apply an angular impulse. The impulse is ignored if the body is not awake.
/// This optionally wakes the body.
///	@param bodyId The body id
/// @param impulse the angular impulse, typically in units of kg*m*m/s
/// @param wake also wake up the body
///	@warning This should be used for one-shot impulses. If you need a steady force,
/// use a force instead, which will work better with the sub-stepping solver.
void b2Body_ApplyAngularImpulse( b2BodyId bodyId, float impulse, bool wake );

/// Get the mass of the body, typically in kilograms
float b2Body_GetMass( b2BodyId bodyId );

/// Get the rotational inertia of the body, typically in kg*m^2
float b2Body_GetRotationalInertia( b2BodyId bodyId );

/// Get the center of mass position of the body in local space
b2Vec2 b2Body_GetLocalCenterOfMass( b2BodyId bodyId );

/// Get the center of mass position of the body in world space
b2Vec2 b2Body_GetWorldCenterOfMass( b2BodyId bodyId );

/// Override the body's mass properties. Normally this is computed automatically using the
///	shape geometry and density. This information is lost if a shape is added or removed or if the
///	body type changes.
void b2Body_SetMassData( b2BodyId bodyId, b2MassData massData );

/// Get the mass data for a body
b2MassData b2Body_GetMassData( b2BodyId bodyId );

/// This update the mass properties to the sum of the mass properties of the shapes.
/// This normally does not need to be called unless you called SetMassData to override
/// the mass and you later want to reset the mass.
///	You may also use this when automatic mass computation has been disabled.
///	You should call this regardless of body type.
void b2Body_ApplyMassFromShapes( b2BodyId bodyId );

/// Set the automatic mass setting. Normally this is set in b2BodyDef before creation.
///	@see b2BodyDef::automaticMass
void b2Body_SetAutomaticMass( b2BodyId bodyId, bool automaticMass );

/// Get the automatic mass setting
bool b2Body_GetAutomaticMass( b2BodyId bodyId );

/// Adjust the linear damping. Normally this is set in b2BodyDef before creation.
void b2Body_SetLinearDamping( b2BodyId bodyId, float linearDamping );

/// Get the current linear damping.
float b2Body_GetLinearDamping( b2BodyId bodyId );

/// Adjust the angular damping. Normally this is set in b2BodyDef before creation.
void b2Body_SetAngularDamping( b2BodyId bodyId, float angularDamping );

/// Get the current angular damping.
float b2Body_GetAngularDamping( b2BodyId bodyId );

/// Adjust the gravity scale. Normally this is set in b2BodyDef before creation.
///	@see b2BodyDef::gravityScale
void b2Body_SetGravityScale( b2BodyId bodyId, float gravityScale );

/// Get the current gravity scale
float b2Body_GetGravityScale( b2BodyId bodyId );

/// @return true if this body is awake
bool b2Body_IsAwake( b2BodyId bodyId );

/// Wake a body from sleep. This wakes the entire island the body is touching.
///	@warning Putting a body to sleep will put the entire island of bodies touching this body to sleep,
///	which can be expensive and possibly unintuitive.
void b2Body_SetAwake( b2BodyId bodyId, bool awake );

/// Enable or disable sleeping for this body. If sleeping is disabled the body will wake.
void b2Body_EnableSleep( b2BodyId bodyId, bool enableSleep );

/// Returns true if sleeping is enabled for this body
bool b2Body_IsSleepEnabled( b2BodyId bodyId );

/// Set the sleep threshold, typically in meters per second
void b2Body_SetSleepThreshold( b2BodyId bodyId, float sleepThreshold );

/// Get the sleep threshold, typically in meters per second.
float b2Body_GetSleepThreshold( b2BodyId bodyId );

/// Returns true if this body is enabled
bool b2Body_IsEnabled( b2BodyId bodyId );

/// Disable a body by removing it completely from the simulation. This is expensive.
void b2Body_Disable( b2BodyId bodyId );

/// Enable a body by adding it to the simulation. This is expensive.
void b2Body_Enable( b2BodyId bodyId );

/// Set this body to have fixed rotation. This causes the mass to be reset in all cases.
void b2Body_SetFixedRotation( b2BodyId bodyId, bool flag );

/// Does this body have fixed rotation?
bool b2Body_IsFixedRotation( b2BodyId bodyId );

/// Set this body to be a bullet. A bullet does continuous collision detection
/// against dynamic bodies (but not other bullets).
void b2Body_SetBullet( b2BodyId bodyId, bool flag );

/// Is this body a bullet?
bool b2Body_IsBullet( b2BodyId bodyId );

/// Enable/disable hit events on all shapes
///	@see b2ShapeDef::enableHitEvents
void b2Body_EnableHitEvents( b2BodyId bodyId, bool enableHitEvents );

/// Get the number of shapes on this body
int b2Body_GetShapeCount( b2BodyId bodyId );

/// Get the shape ids for all shapes on this body, up to the provided capacity.
///	@returns the number of shape ids stored in the user array
int b2Body_GetShapes( b2BodyId bodyId, b2ShapeId* shapeArray, int capacity );

/// Get the number of joints on this body
int b2Body_GetJointCount( b2BodyId bodyId );

/// Get the joint ids for all joints on this body, up to the provided capacity
///	@returns the number of joint ids stored in the user array
int b2Body_GetJoints( b2BodyId bodyId, b2JointId* jointArray, int capacity );

/// Get the maximum capacity required for retrieving all the touching contacts on a body
int b2Body_GetContactCapacity( b2BodyId bodyId );

/// Get the touching contact data for a body
int b2Body_GetContactData( b2BodyId bodyId, b2ContactData* contactData, int capacity );

/// Get the current world AABB that contains all the attached shapes. Note that this may not encompass the body origin.
///	If there are no shapes attached then the returned AABB is empty and centered on the body origin.
b2AABB b2Body_ComputeAABB( b2BodyId bodyId );

/** @} */

/**
 * @defgroup shape Shape
 * Functions to create, destroy, and access.
 * Shapes bind raw geometry to bodies and hold material properties including friction and restitution.
 * @{
 */

/// Create a circle shape and attach it to a body. The shape definition and geometry are fully cloned.
/// Contacts are not created until the next time step.
///	@return the shape id for accessing the shape
b2ShapeId b2CreateCircleShape( b2BodyId bodyId, const b2ShapeDef* def, const b2Circle* circle );

/// Create a line segment shape and attach it to a body. The shape definition and geometry are fully cloned.
/// Contacts are not created until the next time step.
///	@return the shape id for accessing the shape
b2ShapeId b2CreateSegmentShape( b2BodyId bodyId, const b2ShapeDef* def, const b2Segment* segment );

/// Create a capsule shape and attach it to a body. The shape definition and geometry are fully cloned.
/// Contacts are not created until the next time step.
///	@return the shape id for accessing the shape
b2ShapeId b2CreateCapsuleShape( b2BodyId bodyId, const b2ShapeDef* def, const b2Capsule* capsule );

/// Create a polygon shape and attach it to a body. The shape definition and geometry are fully cloned.
/// Contacts are not created until the next time step.
///	@return the shape id for accessing the shape
b2ShapeId b2CreatePolygonShape( b2BodyId bodyId, const b2ShapeDef* def, const b2Polygon* polygon );

/// Destroy a shape
void b2DestroyShape( b2ShapeId shapeId );

/// Shape identifier validation. Provides validation for up to 64K allocations.
bool b2Shape_IsValid( b2ShapeId id );

/// Get the type of a shape
b2ShapeType b2Shape_GetType( b2ShapeId shapeId );

/// Get the id of the body that a shape is attached to
b2BodyId b2Shape_GetBody( b2ShapeId shapeId );

/// Returns true If the shape is a sensor
bool b2Shape_IsSensor( b2ShapeId shapeId );

/// Set the user data for a shape
void b2Shape_SetUserData( b2ShapeId shapeId, void* userData );

/// Get the user data for a shape. This is useful when you get a shape id
///	from an event or query.
void* b2Shape_GetUserData( b2ShapeId shapeId );

/// Set the mass density of a shape, typically in kg/m^2.
///	This will not update the mass properties on the parent body.
///	@see b2ShapeDef::density, b2Body_ApplyMassFromShapes
void b2Shape_SetDensity( b2ShapeId shapeId, float density );

/// Get the density of a shape, typically in kg/m^2
float b2Shape_GetDensity( b2ShapeId shapeId );

/// Set the friction on a shape
///	@see b2ShapeDef::friction
void b2Shape_SetFriction( b2ShapeId shapeId, float friction );

/// Get the friction of a shape
float b2Shape_GetFriction( b2ShapeId shapeId );

/// Set the shape restitution (bounciness)
///	@see b2ShapeDef::restitution
void b2Shape_SetRestitution( b2ShapeId shapeId, float restitution );

/// Get the shape restitution
float b2Shape_GetRestitution( b2ShapeId shapeId );

/// Get the shape filter
b2Filter b2Shape_GetFilter( b2ShapeId shapeId );

/// Set the current filter. This is almost as expensive as recreating the shape.
///	@see b2ShapeDef::filter
void b2Shape_SetFilter( b2ShapeId shapeId, b2Filter filter );

/// Enable sensor events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
///	@see b2ShapeDef::isSensor
void b2Shape_EnableSensorEvents( b2ShapeId shapeId, bool flag );

/// Returns true if sensor events are enabled
bool b2Shape_AreSensorEventsEnabled( b2ShapeId shapeId );

/// Enable contact events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
///	@see b2ShapeDef::enableContactEvents
void b2Shape_EnableContactEvents( b2ShapeId shapeId, bool flag );

/// Returns true if contact events are enabled
bool b2Shape_AreContactEventsEnabled( b2ShapeId shapeId );

/// Enable pre-solve contact events for this shape. Only applies to dynamic bodies. These are expensive
///	and must be carefully handled due to multithreading. Ignored for sensors.
///	@see b2PreSolveFcn
void b2Shape_EnablePreSolveEvents( b2ShapeId shapeId, bool flag );

/// Returns true if pre-solve events are enabled
bool b2Shape_ArePreSolveEventsEnabled( b2ShapeId shapeId );

/// Enable contact hit events for this shape. Ignored for sensors.
///	@see b2WorldDef.hitEventThreshold
void b2Shape_EnableHitEvents( b2ShapeId shapeId, bool flag );

/// Returns true if hit events are enabled
bool b2Shape_AreHitEventsEnabled( b2ShapeId shapeId );

/// Test a point for overlap with a shape
bool b2Shape_TestPoint( b2ShapeId shapeId, b2Vec2 point );

/// Ray cast a shape directly
b2CastOutput b2Shape_RayCast( b2ShapeId shapeId, const b2RayCastInput* input );

/// Get a copy of the shape's circle. Asserts the type is correct.
b2Circle b2Shape_GetCircle( b2ShapeId shapeId );

/// Get a copy of the shape's line segment. Asserts the type is correct.
b2Segment b2Shape_GetSegment( b2ShapeId shapeId );

/// Get a copy of the shape's chain segment. These come from chain shapes.
/// Asserts the type is correct.
b2ChainSegment b2Shape_GetChainSegment( b2ShapeId shapeId );

/// Get a copy of the shape's capsule. Asserts the type is correct.
b2Capsule b2Shape_GetCapsule( b2ShapeId shapeId );

/// Get a copy of the shape's convex polygon. Asserts the type is correct.
b2Polygon b2Shape_GetPolygon( b2ShapeId shapeId );

/// Allows you to change a shape to be a circle or update the current circle.
/// This does not modify the mass properties.
///	@see b2Body_ApplyMassFromShapes
void b2Shape_SetCircle( b2ShapeId shapeId, const b2Circle* circle );

/// Allows you to change a shape to be a capsule or update the current capsule.
/// This does not modify the mass properties.
///	@see b2Body_ApplyMassFromShapes
void b2Shape_SetCapsule( b2ShapeId shapeId, const b2Capsule* capsule );

/// Allows you to change a shape to be a segment or update the current segment.
void b2Shape_SetSegment( b2ShapeId shapeId, const b2Segment* segment );

/// Allows you to change a shape to be a polygon or update the current polygon.
/// This does not modify the mass properties.
///	@see b2Body_ApplyMassFromShapes
void b2Shape_SetPolygon( b2ShapeId shapeId, const b2Polygon* polygon );

/// Get the parent chain id if the shape type is a chain segment, otherwise
/// returns b2_nullChainId.
b2ChainId b2Shape_GetParentChain( b2ShapeId shapeId );

/// Get the maximum capacity required for retrieving all the touching contacts on a shape
int b2Shape_GetContactCapacity( b2ShapeId shapeId );

/// Get the touching contact data for a shape. The provided shapeId will be either shapeIdA or shapeIdB on the contact data.
int b2Shape_GetContactData( b2ShapeId shapeId, b2ContactData* contactData, int capacity );

/// Get the current world AABB
b2AABB b2Shape_GetAABB( b2ShapeId shapeId );

/// Get the closest point on a shape to a target point. Target and result are in world space.
b2Vec2 b2Shape_GetClosestPoint( b2ShapeId shapeId, b2Vec2 target );

/// Chain Shape

/// Create a chain shape
///	@see b2ChainDef for details
b2ChainId b2CreateChain( b2BodyId bodyId, const b2ChainDef* def );

/// Destroy a chain shape
void b2DestroyChain( b2ChainId chainId );

/// Set the chain friction
/// @see b2ChainDef::friction
void b2Chain_SetFriction( b2ChainId chainId, float friction );

/// Set the chain restitution (bounciness)
/// @see b2ChainDef::restitution
void b2Chain_SetRestitution( b2ChainId chainId, float restitution );

/// Chain identifier validation. Provides validation for up to 64K allocations.
bool b2Chain_IsValid( b2ChainId id );

/** @} */

/**
 * @defgroup joint Joint
 * @brief Joints allow you to connect rigid bodies together while allowing various forms of relative motions.
 * @{
 */

/// Destroy a joint
void b2DestroyJoint( b2JointId jointId );

/// Joint identifier validation. Provides validation for up to 64K allocations.
bool b2Joint_IsValid( b2JointId id );

/// Get the joint type
b2JointType b2Joint_GetType( b2JointId jointId );

/// Get body A id on a joint
b2BodyId b2Joint_GetBodyA( b2JointId jointId );

/// Get body B id on a joint
b2BodyId b2Joint_GetBodyB( b2JointId jointId );

/// Get the local anchor on bodyA
b2Vec2 b2Joint_GetLocalAnchorA( b2JointId jointId );

/// Get the local anchor on bodyB
b2Vec2 b2Joint_GetLocalAnchorB( b2JointId jointId );

/// Toggle collision between connected bodies
void b2Joint_SetCollideConnected( b2JointId jointId, bool shouldCollide );

/// Is collision allowed between connected bodies?
bool b2Joint_GetCollideConnected( b2JointId jointId );

/// Set the user data on a joint
void b2Joint_SetUserData( b2JointId jointId, void* userData );

/// Get the user data on a joint
void* b2Joint_GetUserData( b2JointId jointId );

/// Wake the bodies connect to this joint
void b2Joint_WakeBodies( b2JointId jointId );

/// Get the current constraint force for this joint
b2Vec2 b2Joint_GetConstraintForce( b2JointId jointId );

/// Get the current constraint torque for this joint
float b2Joint_GetConstraintTorque( b2JointId jointId );

/**
 * @defgroup distance_joint Distance Joint
 * @brief Functions for the distance joint.
 * @{
 */

/// Create a distance joint
///	@see b2DistanceJointDef for details
b2JointId b2CreateDistanceJoint( b2WorldId worldId, const b2DistanceJointDef* def );

/// Set the rest length of a distance joint
/// @param jointId The id for a distance joint
/// @param length The new distance joint length
void b2DistanceJoint_SetLength( b2JointId jointId, float length );

/// Get the rest length of a distance joint
float b2DistanceJoint_GetLength( b2JointId jointId );

/// Enable/disable the distance joint spring. When disabled the distance joint is rigid.
void b2DistanceJoint_EnableSpring( b2JointId jointId, bool enableSpring );

/// Is the distance joint spring enabled?
bool b2DistanceJoint_IsSpringEnabled( b2JointId jointId );

/// Set the spring stiffness in Hertz
void b2DistanceJoint_SetSpringHertz( b2JointId jointId, float hertz );

/// Set the spring damping ratio, non-dimensional
void b2DistanceJoint_SetSpringDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the spring Hertz
float b2DistanceJoint_GetSpringHertz( b2JointId jointId );

/// Get the spring damping ratio
float b2DistanceJoint_GetSpringDampingRatio( b2JointId jointId );

/// Enable joint limit. The limit only works if the joint spring is enabled. Otherwise the joint is rigid
///	and the limit has no effect.
void b2DistanceJoint_EnableLimit( b2JointId jointId, bool enableLimit );

/// Is the distance joint limit enabled?
bool b2DistanceJoint_IsLimitEnabled( b2JointId jointId );

/// Set the minimum and maximum length parameters of a distance joint
void b2DistanceJoint_SetLengthRange( b2JointId jointId, float minLength, float maxLength );

/// Get the distance joint minimum length
float b2DistanceJoint_GetMinLength( b2JointId jointId );

/// Get the distance joint maximum length
float b2DistanceJoint_GetMaxLength( b2JointId jointId );

/// Get the current length of a distance joint
float b2DistanceJoint_GetCurrentLength( b2JointId jointId );

/// Enable/disable the distance joint motor
void b2DistanceJoint_EnableMotor( b2JointId jointId, bool enableMotor );

/// Is the distance joint motor enabled?
bool b2DistanceJoint_IsMotorEnabled( b2JointId jointId );

/// Set the distance joint motor speed, typically in meters per second
void b2DistanceJoint_SetMotorSpeed( b2JointId jointId, float motorSpeed );

/// Get the distance joint motor speed, typically in meters per second
float b2DistanceJoint_GetMotorSpeed( b2JointId jointId );

/// Set the distance joint maximum motor force, typically in newtons
void b2DistanceJoint_SetMaxMotorForce( b2JointId jointId, float force );

/// Get the distance joint maximum motor force, typically in newtons
float b2DistanceJoint_GetMaxMotorForce( b2JointId jointId );

/// Get the distance joint current motor force, typically in newtons
float b2DistanceJoint_GetMotorForce( b2JointId jointId );

/** @} */

/**
 * @defgroup motor_joint Motor Joint
 * @brief Functions for the motor joint.
 *
 * The motor joint is used to drive the relative transform between two bodies. It takes
 * a relative position and rotation and applies the forces and torques needed to achieve
 * that relative transform over time.
 * @{
 */

/// Create a motor joint
///	@see b2MotorJointDef for details
b2JointId b2CreateMotorJoint( b2WorldId worldId, const b2MotorJointDef* def );

/// Set the motor joint linear offset target
void b2MotorJoint_SetLinearOffset( b2JointId jointId, b2Vec2 linearOffset );

/// Get the motor joint linear offset target
b2Vec2 b2MotorJoint_GetLinearOffset( b2JointId jointId );

/// Set the motor joint angular offset target in radians
void b2MotorJoint_SetAngularOffset( b2JointId jointId, float angularOffset );

/// Get the motor joint angular offset target in radians
float b2MotorJoint_GetAngularOffset( b2JointId jointId );

/// Set the motor joint maximum force, typically in newtons
void b2MotorJoint_SetMaxForce( b2JointId jointId, float maxForce );

/// Get the motor joint maximum force, typically in newtons
float b2MotorJoint_GetMaxForce( b2JointId jointId );

/// Set the motor joint maximum torque, typically in newton-meters
void b2MotorJoint_SetMaxTorque( b2JointId jointId, float maxTorque );

/// Get the motor joint maximum torque, typically in newton-meters
float b2MotorJoint_GetMaxTorque( b2JointId jointId );

/// Set the motor joint correction factor, typically in [0, 1]
void b2MotorJoint_SetCorrectionFactor( b2JointId jointId, float correctionFactor );

/// Get the motor joint correction factor, typically in [0, 1]
float b2MotorJoint_GetCorrectionFactor( b2JointId jointId );

/**@}*/

/**
 * @defgroup mouse_joint Mouse Joint
 * @brief Functions for the mouse joint.
 *
 * The mouse joint is designed for use in the samples application, but you may find it useful in applications where
 * the user moves a rigid body with a cursor.
 * @{
 */

/// Create a mouse joint
///	@see b2MouseJointDef for details
b2JointId b2CreateMouseJoint( b2WorldId worldId, const b2MouseJointDef* def );

/// Set the mouse joint target
void b2MouseJoint_SetTarget( b2JointId jointId, b2Vec2 target );

/// Get the mouse joint target
b2Vec2 b2MouseJoint_GetTarget( b2JointId jointId );

/// Set the mouse joint spring stiffness in Hertz
void b2MouseJoint_SetSpringHertz( b2JointId jointId, float hertz );

/// Get the mouse joint spring stiffness in Hertz
float b2MouseJoint_GetSpringHertz( b2JointId jointId );

/// Set the mouse joint spring damping ratio, non-dimensional
void b2MouseJoint_SetSpringDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the mouse joint damping ratio, non-dimensional
float b2MouseJoint_GetSpringDampingRatio( b2JointId jointId );

/// Set the mouse joint maximum force, typically in newtons
void b2MouseJoint_SetMaxForce( b2JointId jointId, float maxForce );

/// Get the mouse joint maximum force, typically in newtons
float b2MouseJoint_GetMaxForce( b2JointId jointId );

/**@}*/

/**
 * @defgroup prismatic_joint Prismatic Joint
 * @brief A prismatic joint allows for translation along a single axis with no rotation.
 *
 * The prismatic joint is useful for things like pistons and moving platforms, where you want a body to translate
 * along an axis and have no rotation. Also called a *slider* joint.
 * @{
 */

/// Create a prismatic (slider) joint.
///	@see b2PrismaticJointDef for details
b2JointId b2CreatePrismaticJoint( b2WorldId worldId, const b2PrismaticJointDef* def );

/// Enable/disable the joint spring.
void b2PrismaticJoint_EnableSpring( b2JointId jointId, bool enableSpring );

/// Is the prismatic joint spring enabled or not?
bool b2PrismaticJoint_IsSpringEnabled( b2JointId jointId );

/// Set the prismatic joint stiffness in Hertz.
/// This should usually be less than a quarter of the simulation rate. For example, if the simulation
/// runs at 60Hz then the joint stiffness should be 15Hz or less.
void b2PrismaticJoint_SetSpringHertz( b2JointId jointId, float hertz );

/// Get the prismatic joint stiffness in Hertz
float b2PrismaticJoint_GetSpringHertz( b2JointId jointId );

/// Set the prismatic joint damping ratio (non-dimensional)
void b2PrismaticJoint_SetSpringDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the prismatic spring damping ratio (non-dimensional)
float b2PrismaticJoint_GetSpringDampingRatio( b2JointId jointId );

/// Enable/disable a prismatic joint limit
void b2PrismaticJoint_EnableLimit( b2JointId jointId, bool enableLimit );

/// Is the prismatic joint limit enabled?
bool b2PrismaticJoint_IsLimitEnabled( b2JointId jointId );

/// Get the prismatic joint lower limit
float b2PrismaticJoint_GetLowerLimit( b2JointId jointId );

/// Get the prismatic joint upper limit
float b2PrismaticJoint_GetUpperLimit( b2JointId jointId );

/// Set the prismatic joint limits
void b2PrismaticJoint_SetLimits( b2JointId jointId, float lower, float upper );

/// Enable/disable a prismatic joint motor
void b2PrismaticJoint_EnableMotor( b2JointId jointId, bool enableMotor );

/// Is the prismatic joint motor enabled?
bool b2PrismaticJoint_IsMotorEnabled( b2JointId jointId );

/// Set the prismatic joint motor speed, typically in meters per second
void b2PrismaticJoint_SetMotorSpeed( b2JointId jointId, float motorSpeed );

/// Get the prismatic joint motor speed, typically in meters per second
float b2PrismaticJoint_GetMotorSpeed( b2JointId jointId );

/// Set the prismatic joint maximum motor force, typically in newtons
void b2PrismaticJoint_SetMaxMotorForce( b2JointId jointId, float force );

/// Get the prismatic joint maximum motor force, typically in newtons
float b2PrismaticJoint_GetMaxMotorForce( b2JointId jointId );

/// Get the prismatic joint current motor force, typically in newtons
float b2PrismaticJoint_GetMotorForce( b2JointId jointId );

/** @} */

/**
 * @defgroup revolute_joint Revolute Joint
 * @brief A revolute joint allows for relative rotation in the 2D plane with no relative translation.
 *
 * The revolute joint is probably the most common joint. It can be used for ragdolls and chains.
 * Also called a *hinge* or *pin* joint.
 * @{
 */

/// Create a revolute joint
///	@see b2RevoluteJointDef for details
b2JointId b2CreateRevoluteJoint( b2WorldId worldId, const b2RevoluteJointDef* def );

/// Enable/disable the revolute joint spring
void b2RevoluteJoint_EnableSpring( b2JointId jointId, bool enableSpring );

/// It the revolute angular spring enabled?
bool b2RevoluteJoint_IsSpringEnabled( b2JointId jointId );

/// Set the revolute joint spring stiffness in Hertz
void b2RevoluteJoint_SetSpringHertz( b2JointId jointId, float hertz );

/// Get the revolute joint spring stiffness in Hertz
float b2RevoluteJoint_GetSpringHertz( b2JointId jointId );

/// Set the revolute joint spring damping ratio, non-dimensional
void b2RevoluteJoint_SetSpringDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the revolute joint spring damping ratio, non-dimensional
float b2RevoluteJoint_GetSpringDampingRatio( b2JointId jointId );

/// Get the revolute joint current angle in radians relative to the reference angle
///	@see b2RevoluteJointDef::referenceAngle
float b2RevoluteJoint_GetAngle( b2JointId jointId );

/// Enable/disable the revolute joint limit
void b2RevoluteJoint_EnableLimit( b2JointId jointId, bool enableLimit );

/// Is the revolute joint limit enabled?
bool b2RevoluteJoint_IsLimitEnabled( b2JointId jointId );

/// Get the revolute joint lower limit in radians
float b2RevoluteJoint_GetLowerLimit( b2JointId jointId );

/// Get the revolute joint upper limit in radians
float b2RevoluteJoint_GetUpperLimit( b2JointId jointId );

/// Set the revolute joint limits in radians
void b2RevoluteJoint_SetLimits( b2JointId jointId, float lower, float upper );

/// Enable/disable a revolute joint motor
void b2RevoluteJoint_EnableMotor( b2JointId jointId, bool enableMotor );

/// Is the revolute joint motor enabled?
bool b2RevoluteJoint_IsMotorEnabled( b2JointId jointId );

/// Set the revolute joint motor speed in radians per second
void b2RevoluteJoint_SetMotorSpeed( b2JointId jointId, float motorSpeed );

/// Get the revolute joint motor speed in radians per second
float b2RevoluteJoint_GetMotorSpeed( b2JointId jointId );

/// Get the revolute joint current motor torque, typically in newton-meters
float b2RevoluteJoint_GetMotorTorque( b2JointId jointId );

/// Set the revolute joint maximum motor torque, typically in newton-meters
void b2RevoluteJoint_SetMaxMotorTorque( b2JointId jointId, float torque );

/// Get the revolute joint maximum motor torque, typically in newton-meters
float b2RevoluteJoint_GetMaxMotorTorque( b2JointId jointId );

/**@}*/

/**
 * @defgroup weld_joint Weld Joint
 * @brief A weld joint fully constrains the relative transform between two bodies while allowing for springiness
 *
 * A weld joint constrains the relative rotation and translation between two bodies. Both rotation and translation
 * can have damped springs.
 *
 * @note The accuracy of weld joint is limited by the accuracy of the solver. Long chains of weld joints may flex.
 * @{
 */

/// Create a weld joint
///	@see b2WeldJointDef for details
b2JointId b2CreateWeldJoint( b2WorldId worldId, const b2WeldJointDef* def );

/// Set the weld joint linear stiffness in Hertz. 0 is rigid.
void b2WeldJoint_SetLinearHertz( b2JointId jointId, float hertz );

/// Get the weld joint linear stiffness in Hertz
float b2WeldJoint_GetLinearHertz( b2JointId jointId );

/// Set the weld joint linear damping ratio (non-dimensional)
void b2WeldJoint_SetLinearDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the weld joint linear damping ratio (non-dimensional)
float b2WeldJoint_GetLinearDampingRatio( b2JointId jointId );

/// Set the weld joint angular stiffness in Hertz. 0 is rigid.
void b2WeldJoint_SetAngularHertz( b2JointId jointId, float hertz );

/// Get the weld joint angular stiffness in Hertz
float b2WeldJoint_GetAngularHertz( b2JointId jointId );

/// Set weld joint angular damping ratio, non-dimensional
void b2WeldJoint_SetAngularDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the weld joint angular damping ratio, non-dimensional
float b2WeldJoint_GetAngularDampingRatio( b2JointId jointId );

/** @} */

/**
 * @defgroup wheel_joint Wheel Joint
 * The wheel joint can be used to simulate wheels on vehicles.
 *
 * The wheel joint restricts body B to move along a local axis in body A. Body B is free to
 * rotate. Supports a linear spring, linear limits, and a rotational motor.
 *
 * @{
 */

/// Create a wheel joint
///	@see b2WheelJointDef for details
b2JointId b2CreateWheelJoint( b2WorldId worldId, const b2WheelJointDef* def );

/// Enable/disable the wheel joint spring
void b2WheelJoint_EnableSpring( b2JointId jointId, bool enableSpring );

/// Is the wheel joint spring enabled?
bool b2WheelJoint_IsSpringEnabled( b2JointId jointId );

/// Set the wheel joint stiffness in Hertz
void b2WheelJoint_SetSpringHertz( b2JointId jointId, float hertz );

/// Get the wheel joint stiffness in Hertz
float b2WheelJoint_GetSpringHertz( b2JointId jointId );

/// Set the wheel joint damping ratio, non-dimensional
void b2WheelJoint_SetSpringDampingRatio( b2JointId jointId, float dampingRatio );

/// Get the wheel joint damping ratio, non-dimensional
float b2WheelJoint_GetSpringDampingRatio( b2JointId jointId );

/// Enable/disable the wheel joint limit
void b2WheelJoint_EnableLimit( b2JointId jointId, bool enableLimit );

/// Is the wheel joint limit enabled?
bool b2WheelJoint_IsLimitEnabled( b2JointId jointId );

/// Get the wheel joint lower limit
float b2WheelJoint_GetLowerLimit( b2JointId jointId );

/// Get the wheel joint upper limit
float b2WheelJoint_GetUpperLimit( b2JointId jointId );

/// Set the wheel joint limits
void b2WheelJoint_SetLimits( b2JointId jointId, float lower, float upper );

/// Enable/disable the wheel joint motor
void b2WheelJoint_EnableMotor( b2JointId jointId, bool enableMotor );

/// Is the wheel joint motor enabled?
bool b2WheelJoint_IsMotorEnabled( b2JointId jointId );

/// Set the wheel joint motor speed in radians per second
void b2WheelJoint_SetMotorSpeed( b2JointId jointId, float motorSpeed );

/// Get the wheel joint motor speed in radians per second
float b2WheelJoint_GetMotorSpeed( b2JointId jointId );

/// Set the wheel joint maximum motor torque, typically in newton-meters
void b2WheelJoint_SetMaxMotorTorque( b2JointId jointId, float torque );

/// Get the wheel joint maximum motor torque, typically in newton-meters
float b2WheelJoint_GetMaxMotorTorque( b2JointId jointId );

/// Get the wheel joint current motor torque, typically in newton-meters
float b2WheelJoint_GetMotorTorque( b2JointId jointId );

// MISC

b2Transform b2MakeTransform(float x, float y, float angle_rad);

// MULTI THREADING

typedef struct b2TaskData {
    b2TaskCallback* callback;
    void* context;
} b2TaskData;

typedef struct b2UserContext {
    void* scheduler;
    void* tasks[256];
    b2TaskData task_data[256];
    int n_tasks;
} b2UserContext;

extern void b2InvokeTask(uint32_t start, uint32_t end, uint32_t threadIndex, void* context);

// RAY CAST

typedef float b2CastResultFcnWrapper( b2ShapeId* shapeId, b2Vec2* point, b2Vec2* normal, float fraction);

float b2CastRayWrapperCallback(b2ShapeId shape_id, b2Vec2 point, b2Vec2 normal, float fraction, void* context );
void b2World_CastRayWrapper(b2WorldId world, b2Vec2 origin, b2Vec2 destination, b2QueryFilter filter, b2CastResultFcnWrapper* callback);

// OVERLAP

typedef bool b2OverlapResultFcnWrapper(b2ShapeId* shapeId);
bool b2OverlapResultWrapperCallback(b2ShapeId, void* context);

void b2World_OverlapCircleWrapper(
    b2WorldId world,
    b2Circle* circle,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

void b2World_OverlapAABBWrapper(
    b2WorldId world,
    b2AABB aabb,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

void b2World_OverlapPolygonWrapper(
    b2WorldId world,
    b2Polygon* polygon,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

void b2World_OverlapCapsuleWrapper(
    b2WorldId world,
    b2Capsule* capsule,
    b2Transform transform,
    b2QueryFilter filter,
    b2OverlapResultFcnWrapper* callback
);

// DEBUG DRAW

void b2HexColorToRGB(int hexColor, float* red, float* green, float* blue);

typedef void b2DrawPolygonFcn(const b2Vec2* vertices, int vertex_count, float red, float green, float blue);
typedef void b2DrawSolidPolygonFcn(b2Transform* transform, const b2Vec2* vertices, int vertex_count, float radius, float red, float green, float blue);
typedef void b2DrawCircleFcn(b2Vec2* center, float radius, float red, float green, float blue);
typedef void b2DrawSolidCircleFcn(b2Transform* transform, float radius, float red, float green, float blue);
typedef void b2DrawSolidCapsuleFcn(b2Vec2* p1, b2Vec2* p2, float radius, float red, float green, float blue);
typedef void b2DrawSegmentFcn(b2Vec2* p1, b2Vec2* p2, float red, float green, float blue);
typedef void b2DrawTransformFcn(b2Transform*);
typedef void b2DrawPointFcn(b2Vec2* p, float size, float red, float green, float blue);
typedef void b2DrawString(b2Vec2* p, const char* s);

typedef struct b2DebugDrawContext {
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

void b2DebugDraw_DrawPolygon(const b2Vec2* vertices, int vertexCount, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawSolidPolygon(b2Transform transform, const b2Vec2* vertices, int vertexCount, float radius, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawCircle(b2Vec2 center, float radius, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawSolidCircle(b2Transform transform, float radius, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawSolidCapsule(b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawSegment(b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context_ptr);
void b2DebugDraw_DrawTransform(b2Transform transform, void* context);
void b2DebugDraw_DrawPoint(b2Vec2 p, float size, b2HexColor color, void* context);
void b2DebugDraw_DrawString(b2Vec2 p, const char* s, void* context);

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
);


// custom wrapped
void rtmidi_message_callback(double timeStamp, const unsigned char* message,
size_t messageSize, void *userData);