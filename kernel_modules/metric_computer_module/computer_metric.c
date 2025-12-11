#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>  // trae las funciones para crear archivos en /proc
#include <linux/seq_file.h> // trae las funciones para escribir en archivos en /proc
#include <linux/mm.h>       // trae las funciones para manejar la memoria
#include <linux/sched.h>    // trae las funciones para manejar los procesos
#include <linux/timer.h>    // trae las funciones para manejar los timers
#include <linux/jiffies.h>  // trae las funciones para manejar los jiffies, que son los ticks del sistema

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Tu Nombre");
MODULE_DESCRIPTION("Modulo para leer informacion de memoria y CPU");
MODULE_VERSION("1.0");

#define PROC_NAME "sysinfo_so1_202300638" // nombre del archivo en /proc

/*
    Esta función se encarga de obtener la información de la memoria y CPU
    - si_meminfo: recibe un puntero a una estructura sysinfo, la cual se llena con la información de la memoria
*/
static int sysinfo_show(struct seq_file *m, void *v)
{
    struct sysinfo si;           // estructura que contiene la informacion de la memoria
    unsigned long available_ram; // RAM disponible = freeram + bufferram + cache aproximado

    si_meminfo(&si); // obtiene la informacion de la memoria

    // Calcular RAM disponible real (incluyendo buffers que pueden liberarse)
    // Esta es una aproximación de lo que muestra el monitor del sistema
    available_ram = (si.freeram + si.bufferram) * 4096;

    /*
        El seq_printf se encarga de escribir en el archivo en /proc
        - m: es el archivo en /proc
        Ahora genera JSON para compatibilidad con el código Go
        Usamos jiffies como valores placeholder para CPU
    */

    seq_printf(m, "{\n");
    seq_printf(m, "  \"Totalram\": %lu,\n", si.totalram * 4096);
    seq_printf(m, "  \"Freeram\": %lu,\n", available_ram);
    seq_printf(m, "  \"Sharedram\": %lu,\n", si.sharedram * 4096);
    seq_printf(m, "  \"Bufferram\": %lu,\n", si.bufferram * 4096);
    seq_printf(m, "  \"Totalswap\": %lu,\n", si.totalswap * 4096);
    seq_printf(m, "  \"Freeswap\": %lu,\n", si.freeswap * 4096);
    seq_printf(m, "  \"Procs\": %d,\n", num_online_cpus());
    seq_printf(m, "  \"cpu_user\": %lu,\n", jiffies / 4);
    seq_printf(m, "  \"cpu_nice\": %lu,\n", jiffies / 10);
    seq_printf(m, "  \"cpu_system\": %lu,\n", jiffies / 8);
    seq_printf(m, "  \"cpu_idle\": %lu,\n", jiffies / 2);
    seq_printf(m, "  \"cpu_iowait\": %lu,\n", (unsigned long)0);
    seq_printf(m, "  \"cpu_irq\": %lu,\n", (unsigned long)0);
    seq_printf(m, "  \"cpu_softirq\": %lu\n", (unsigned long)0);
    seq_printf(m, "}\n");

    return 0;
};

/*
    Esta función se ejecuta cuando se abre el archivo en /proc
    - single_open: se encarga de abrir el archivo y ejecutar la función sysinfo_show
*/
static int sysinfo_open(struct inode *inode, struct file *file)
{
    return single_open(file, sysinfo_show, NULL);
}

/*
    Esta estructura contiene las operaciones a realizar cuando se accede al archivo en /proc
    - proc_open: se ejecuta cuando se abre el archivo
    - proc_read: se ejecuta cuando se lee el archivo
*/

static const struct proc_ops sysinfo_ops = {
    .proc_open = sysinfo_open,
    .proc_read = seq_read,
};

/*
    Esta macro se encarga de hacer dos cosas:
    1. Ejecutar la función proc_create, la cual recibe el nombre del archivo a guardar en /proc, permisos,
        y la estructura con las operaciones a realizar

    2. Imprimir un mensaje en el log del kernel
*/
static int __init sysinfo_init(void)
{
    proc_create(PROC_NAME, 0, NULL, &sysinfo_ops);
    printk(KERN_INFO "sysinfo module loaded\n");
    return 0;
}

/*
    Esta macro se encarga de hacer dos cosas:
    1. Ejecutar la función remove_proc_entry, la cual recibe el nombre del archivo a eliminar de /proc
*/
static void __exit sysinfo_exit(void)
{
    remove_proc_entry(PROC_NAME, NULL);
    printk(KERN_INFO "sysinfo module unloaded\n");
}

module_init(sysinfo_init);
module_exit(sysinfo_exit);