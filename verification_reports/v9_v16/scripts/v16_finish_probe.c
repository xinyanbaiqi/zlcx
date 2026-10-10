/* 只读VPI观察器：结束时报告全局精度下的仿真时间，不改任何RTL/TB信号。 */
#include <stdint.h>
#include <inttypes.h>
#include <vpi_user.h>

static PLI_INT32 report_finish(p_cb_data callback)
{
    s_vpi_time now = {0};
    uint64_t ticks;
    (void)callback;
    now.type = vpiSimTime;
    vpi_get_time(NULL, &now);
    ticks = ((uint64_t)now.high << 32) | now.low;
    vpi_printf("V16_FINISH ticks=%" PRIu64 " precision_exp=%d\n",
               ticks, vpi_get(vpiTimePrecision, NULL));
    return 0;
}

static void register_finish(void)
{
    s_cb_data callback = {0};
    callback.reason = cbEndOfSimulation;
    callback.cb_rtn = report_finish;
    vpi_register_cb(&callback);
}

void (*vlog_startup_routines[])(void) = {register_finish, 0};
