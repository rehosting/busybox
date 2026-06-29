#ifndef BUSYBOX_PORTALCALL_H
#define BUSYBOX_PORTALCALL_H

#include <stdint.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <unistd.h>

#if __SIZEOF_POINTER__ == 8
#define PORTAL_MAGIC ((unsigned long)0xc1d1e1f1)
#else
#define PORTAL_MAGIC ((unsigned int)0xc1d1e1f1)
#endif

static inline unsigned long portal_call(unsigned long user_magic, int argc,
                                        const uint64_t *args)
{
    return (unsigned long)syscall(SYS_sendto, PORTAL_MAGIC, user_magic, argc, args, 0, 0);
}

#ifdef MAGIC_VALUE
#include <stdlib.h>  /* getenv */
#define RETRY 0xDEADBEEF

/*
 * Shell-coverage hypercalls are emitted only for the firmware-under-analysis.
 * Penguin exports IGLOO_NO_SHELL_COV=1 in its own infrastructure environment
 * (boot machinery + the vpnguin/console/guesthopper helpers) and clears it at
 * the handoff into the firmware init, so everything in the infra environment
 * stays silent. The marker is inherited across fork/exec, so the whole infra
 * subtree -- including fork-without-exec subshells -- is covered without any
 * per-process tracking on the host. Absence of the marker means "report", so a
 * plain busybox outside Penguin behaves exactly as before.
 */
static inline int igloo_shell_cov_suppressed(void)
{
    static int cached = -1;
    if (cached < 0)
        cached = getenv("IGLOO_NO_SHELL_COV") != NULL;
    return cached;
}

static inline int portal_hc(int hc_type, void **s, int len)
{
    uint64_t ret = hc_type;
    int y = 0;

    if (igloo_shell_cov_suppressed())
        return 0;
    do {
        ret = MAGIC_VALUE;
        volatile int x = 0;
        for (int i = 0; i < len; i++) {
            x |= *(((int *)s[i]) + y);
        }
        y++;
        {
            uint64_t args[3] = {
                (uint64_t)hc_type,
                (uint64_t)s,
                (uint64_t)len,
            };
            ret = portal_call(MAGIC_VALUE, 3, args);
        }
    } while (ret == RETRY);

    return ret;
}
#endif

#endif
