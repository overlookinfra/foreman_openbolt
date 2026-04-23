# Usage

(all screenshots were taken on Foreman 3.17)

After installation, you will see a new UI element

![foreman UI menu screenshot](../ext/foreman-ui-menu.png)

The "Launch Task" option allows you to select any smartproxy with the `openbolt` feature (which is available when the OpenBolt Smartproxy plugin is installed).
Afterwards you can select N targets to run the task and select an available task from the selected Smartproxy.
On the right side you can configure OpenBolt connection settings.

![launch task detail view](../ext/foreman-launch-task.png)

After selecting a task, the task metadata is fetched and shown.
Additional input elements will appear, if the task support it.

![service task metadata](../ext/task-metadata-minimal.png)

The metadata can contains a description and datatypes for tasks.
Those information can be shown as well.

![service task detailed metadata](../ext/task-metadata.png)

While the task is running, the UI polls the status from the smart proxy.

![task loading screen](../ext/task-running.png)

After the task finished, it will display a success for failure page.

![failed task view](../ext/task-execution-details.png)

You can also see the used parameters for a task.

![task used parameters](../ext/task-task-details.png)

We also display the used OpenBolt command line, in case you want to manually run it or debug it.

![display used OpenBolt command](../ext/task-log-output.png)

OpenBolt returns JSON for executed tasks.
That's visible in the UI.
For failed tasks but also for passed tasks.

![failed task output](../ext/task-result.png)

![service task passed on two nodes](../ext/task-successful-result.png)
