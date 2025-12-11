#include <linux/module.h>
#include <linux/export-internal.h>
#include <linux/compiler.h>

MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x003b23f9, "single_open" },
	{ 0xc7ffe1aa, "si_meminfo" },
	{ 0x1df1459a, "vm_node_stat" },
	{ 0xf2c4f3f1, "seq_printf" },
	{ 0x2182515b, "__num_online_cpus" },
	{ 0x058c185a, "jiffies" },
	{ 0xd272d446, "__stack_chk_fail" },
	{ 0x33c78c8a, "remove_proc_entry" },
	{ 0xbd4e501f, "seq_read" },
	{ 0xd272d446, "__fentry__" },
	{ 0x82c6f73b, "proc_create" },
	{ 0xe8213e80, "_printk" },
	{ 0xd272d446, "__x86_return_thunk" },
	{ 0xba157484, "module_layout" },
};

static const u32 ____version_ext_crcs[]
__used __section("__version_ext_crcs") = {
	0x003b23f9,
	0xc7ffe1aa,
	0x1df1459a,
	0xf2c4f3f1,
	0x2182515b,
	0x058c185a,
	0xd272d446,
	0x33c78c8a,
	0xbd4e501f,
	0xd272d446,
	0x82c6f73b,
	0xe8213e80,
	0xd272d446,
	0xba157484,
};
static const char ____version_ext_names[]
__used __section("__version_ext_names") =
	"single_open\0"
	"si_meminfo\0"
	"vm_node_stat\0"
	"seq_printf\0"
	"__num_online_cpus\0"
	"jiffies\0"
	"__stack_chk_fail\0"
	"remove_proc_entry\0"
	"seq_read\0"
	"__fentry__\0"
	"proc_create\0"
	"_printk\0"
	"__x86_return_thunk\0"
	"module_layout\0"
;

MODULE_INFO(depends, "");


MODULE_INFO(srcversion, "8EC9DD2E120453ACD546418");
