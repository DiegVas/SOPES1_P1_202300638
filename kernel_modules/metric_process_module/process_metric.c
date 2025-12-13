#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/string.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/timer.h>
#include <linux/jiffies.h>
#include <linux/uaccess.h>
#include <linux/tty.h>
#include <linux/sched/signal.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/sched/mm.h>
#include <linux/binfmts.h>
#include <linux/timekeeping.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Tu Nombre");
MODULE_DESCRIPTION("Modulo para leer informacion de memoria y CPU en JSON");
MODULE_VERSION("1.0");

#define PROC_NAME "continfo_so1_202300638"
#define MAX_CMDLINE_LENGTH 256

// Función para imprimir string escapado para JSON
static void print_escaped_string(struct seq_file *m, const char *str)
{
    int i;
    if (!str)
    {
        seq_printf(m, "N/A");
        return;
    }

    for (i = 0; str[i] != '\0'; i++)
    {
        switch (str[i])
        {
        case '"':
            seq_printf(m, "\\\"");
            break;
        case '\\':
            seq_printf(m, "\\\\");
            break;
        case '\n':
            seq_printf(m, "\\n");
            break;
        case '\r':
            seq_printf(m, "\\r");
            break;
        case '\t':
            seq_printf(m, "\\t");
            break;
        case '\b':
            seq_printf(m, "\\b");
            break;
        case '\f':
            seq_printf(m, "\\f");
            break;
        default:
            if (str[i] < 32 || str[i] > 126)
            {
                // Caracteres no imprimibles
                seq_printf(m, " ");
            }
            else
            {
                seq_printf(m, "%c", str[i]);
            }
            break;
        }
    }
}

// Función para obtener la línea de comandos de un proceso
static char *get_process_cmdline(struct task_struct *task)
{
    struct mm_struct *mm;
    char *cmdline;
    unsigned long arg_start = 0, arg_end = 0;
    int len = 0, i;

    cmdline = kmalloc(MAX_CMDLINE_LENGTH, GFP_KERNEL);
    if (!cmdline)
        return NULL;

    mm = get_task_mm(task);
    if (!mm)
    {
        kfree(cmdline);
        return NULL;
    }

    /* Kernel >= 6.8 usa mmap_lock */
    down_read(&mm->mmap_lock);
    arg_start = mm->arg_start;
    arg_end = mm->arg_end;
    up_read(&mm->mmap_lock);

    if (arg_end > arg_start)
        len = arg_end - arg_start;
    else
        len = 0;

    if (len > MAX_CMDLINE_LENGTH - 1)
        len = MAX_CMDLINE_LENGTH - 1;

    if (len > 0)
    {
        if (access_process_vm(task, arg_start, cmdline, len, 0) != len)
        {
            mmput(mm);
            kfree(cmdline);
            return NULL;
        }
    }
    else
    {
        cmdline[0] = '\0';
    }

    cmdline[len] = '\0';

    for (i = 0; i < len; i++)
        if (cmdline[i] == '\0')
            cmdline[i] = ' ';

    while (len > 0 && cmdline[len - 1] == ' ')
        cmdline[--len] = '\0';

    mmput(mm);
    return cmdline;
}

// Función para mostrar la información en formato JSON
static int sysinfo_show(struct seq_file *m, void *v)
{
    struct sysinfo si;
    struct task_struct *task;
    unsigned long total_jiffies;
    int first_process = 1;
    int process_count = 0;

    // Obtenemos la información de memoria
    si_meminfo(&si);
    total_jiffies = jiffies;

    seq_printf(m, "{\n");
    seq_printf(m, "  \"Totalram\": %lu,\n", si.totalram << (PAGE_SHIFT - 10));
    seq_printf(m, "  \"Freeram\": %lu,\n", si.freeram << (PAGE_SHIFT - 10));

    // Contar todos los procesos
    for_each_process(task)
    {
        process_count++;
    }

    seq_printf(m, "  \"Procs\": %d,\n", process_count);
    seq_printf(m, "  \"Processes\": [\n");

    // Iterar sobre todos los procesos del sistema
    for_each_process(task)
    {
        unsigned long vsz = 0;
        unsigned long rss = 0;
        unsigned long totalram = si.totalram << (PAGE_SHIFT - 10);
        unsigned long mem_usage = 0;
        unsigned long cpu_usage = 0;
        char *cmdline = NULL;

        // Obtenemos los valores de VSZ y RSS
        if (task->mm)
        {
            vsz = task->mm->total_vm << (PAGE_SHIFT - 10);
            rss = get_mm_rss(task->mm) << (PAGE_SHIFT - 10);

            // Calcular porcentaje de memoria (multiplicamos por 1000 para tener 1 decimal)
            if (totalram > 0)
                mem_usage = (rss * 1000) / totalram;
        }

        // Calcular uso de CPU
        unsigned long total_time = task->utime + task->stime;
        if (total_jiffies > 0)
        {
            cpu_usage = (total_time * 10000) / total_jiffies;
            // Ajustar por número de CPUs
            cpu_usage = cpu_usage / num_online_cpus();
        }

        // Obtener línea de comandos
        cmdline = get_process_cmdline(task);

        // Obtener estado del proceso
        char state;
        switch (task->__state)
        {
        case TASK_RUNNING:
            state = 'R';
            break;
        case TASK_INTERRUPTIBLE:
            state = 'S';
            break;
        case TASK_UNINTERRUPTIBLE:
            state = 'D';
            break;
        case __TASK_STOPPED:
            state = 'T';
            break;
        case __TASK_TRACED:
            state = 't';
            break;
        case EXIT_ZOMBIE:
            state = 'Z';
            break;
        case EXIT_DEAD:
            state = 'X';
            break;
        default:
            state = '?';
            break;
        }

        // Imprimir separador entre procesos
        if (!first_process)
        {
            seq_printf(m, ",\n");
        }
        else
        {
            first_process = 0;
        }

        // Imprimir información del proceso
        seq_printf(m, "    {\n");
        seq_printf(m, "      \"PID\": %d,\n", task->pid);
        seq_printf(m, "      \"Name\": \"");
        print_escaped_string(m, task->comm);
        seq_printf(m, "\",\n");
        seq_printf(m, "      \"Cmdline\": \"");
        print_escaped_string(m, cmdline);
        seq_printf(m, "\",\n");
        seq_printf(m, "      \"vsz\": %lu,\n", vsz);
        seq_printf(m, "      \"rss\": %lu,\n", rss);
        seq_printf(m, "      \"Memory_Usage\": %lu.%lu,\n", mem_usage / 10, mem_usage % 10);
        seq_printf(m, "      \"CPU_Usage\": %lu.%02lu,\n", cpu_usage / 100, cpu_usage % 100);
        seq_printf(m, "      \"State\": \"%c\"\n", state);
        seq_printf(m, "    }");

        // Liberar memoria de cmdline
        if (cmdline)
        {
            kfree(cmdline);
        }
    }

    seq_printf(m, "\n  ]\n}\n");
    return 0;
}

// Función que se ejecuta al abrir el archivo /proc
static int sysinfo_open(struct inode *inode, struct file *file)
{
    return single_open(file, sysinfo_show, NULL);
}

// Estructura que contiene las operaciones del archivo /proc
static const struct proc_ops sysinfo_ops = {
    .proc_open = sysinfo_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

// Función de inicialización del módulo
static int __init sysinfo_init(void)
{
    struct proc_dir_entry *entry;
    entry = proc_create(PROC_NAME, 0444, NULL, &sysinfo_ops);
    if (!entry)
    {
        printk(KERN_ERR "Error al crear /proc/%s\n", PROC_NAME);
        return -ENOMEM;
    }
    printk(KERN_INFO "continfo_json modulo cargado: /proc/%s creado\n", PROC_NAME);
    return 0;
}

// Función de limpieza del módulo
static void __exit sysinfo_exit(void)
{
    remove_proc_entry(PROC_NAME, NULL);
    printk(KERN_INFO "continfo_json modulo desinstalado\n");
}

module_init(sysinfo_init);
module_exit(sysinfo_exit);