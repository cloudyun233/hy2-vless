import { memo } from 'react';
import TaskItem from './TaskItem';
import EmptyState from '../common/EmptyState';

const TaskList = memo(function TaskList({ tasks, onDelete, onStopSeed, onRetry }) {
  if (!tasks.length) {
    return <EmptyState icon="📭" message="暂无下载任务，粘贴磁力链接开始吧。" />;
  }

  return (
    <div>
      {tasks.map((task) => (
        <TaskItem
          key={task.id}
          task={task}
          onDelete={onDelete}
          onStopSeed={onStopSeed}
          onRetry={onRetry}
        />
      ))}
    </div>
  );
});

export default TaskList;
