/* CPython ABI boundary: a debug BUI build can link release-only Python.
 * SPDX-License-Identifier: GPL-2.0-or-later */
#pragma once

#define PY_SSIZE_T_CLEAN
#if defined(BUI_PYTHON_RELEASE_ABI) && defined(_DEBUG)
#  define BUI_RESTORE_CRT_DEBUG
#  pragma push_macro("_DEBUG")
#  undef _DEBUG
#endif

#include <Python.h>

#ifdef BUI_RESTORE_CRT_DEBUG
#  pragma pop_macro("_DEBUG")
#  undef BUI_RESTORE_CRT_DEBUG
#endif
