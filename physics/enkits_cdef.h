typedef struct enkiParamsTaskSet
{
    void*    pArgs;
    uint32_t setSize;
    uint32_t minRange;
    int      priority;
} enkiParamsTaskSet;

typedef void (*enkiProfilerCallbackFunc)( uint32_t threadnum_ );
typedef struct enkiProfilerCallbacks
{
    enkiProfilerCallbackFunc threadStart;
    enkiProfilerCallbackFunc threadStop;
    enkiProfilerCallbackFunc waitForNewTaskSuspendStart;      // thread suspended waiting for new tasks
    enkiProfilerCallbackFunc waitForNewTaskSuspendStop;       // thread unsuspended
    enkiProfilerCallbackFunc waitForTaskCompleteStart;        // thread waiting for task completion
    enkiProfilerCallbackFunc waitForTaskCompleteStop;         // thread stopped waiting
    enkiProfilerCallbackFunc waitForTaskCompleteSuspendStart; // thread suspended waiting task completion
    enkiProfilerCallbackFunc waitForTaskCompleteSuspendStop;  // thread unsuspended
} enkiProfilerCallbacks;

typedef void  (*enkiFreeFunc)(  void* ptr_,    size_t size_, void* userData_, const char* file_, int line_ );
typedef void* (*enkiAllocFunc)( size_t align_, size_t size_, void* userData_, const char* file_, int line_ );
typedef struct enkiCustomAllocator
{
    enkiAllocFunc alloc;
    enkiFreeFunc  free;
    void*         userData;
} enkiCustomAllocator;

typedef struct enkiTaskSchedulerConfig
{
    uint32_t              numTaskThreadsToCreate;
    uint32_t              numExternalTaskThreads;
    struct enkiProfilerCallbacks profilerCallbacks;
    struct enkiCustomAllocator   customAllocator;
} enkiTaskSchedulerConfig;

void enkiSetParamsTaskSet( void* pTaskSet_, enkiParamsTaskSet params_);
void enkiAddTaskSet( void* pETS_, void* pTaskSet_ );
void enkiWaitForTaskSet( void* pETS_, void* pTaskSet_ );

void* enkiNewTaskScheduler();
void enkiDeleteTaskScheduler(void* task_scheduler);

struct enkiTaskSchedulerConfig enkiGetTaskSchedulerConfig( void* pETS_ );
void enkiInitTaskSchedulerWithConfig( void* pETS_, struct enkiTaskSchedulerConfig config_ );

typedef void (* enkiTaskExecuteRange)( uint32_t start_, uint32_t end_, uint32_t threadnum_, void* pArgs_ );
void* enkiCreateTaskSet( void* pETS_, enkiTaskExecuteRange taskFunc_  );
void enkiDeleteTaskSet( void* task_scheduler, void* task_set);

void* malloc(size_t size);
void free(void *ptr);


