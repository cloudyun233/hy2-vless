import { memo } from 'react';
import Button from '../common/Button';
import ProgressBar from '../common/ProgressBar';

const healthDot = {
  good: { color: 'var(--teal)', title: '连接良好' },
  fair: { color: 'var(--gold)', title: '连接一般' },
  poor: { color: 'var(--danger)', title: '节点较少' },
  error: { color: 'var(--danger)', title: '下载失败' },
  queued: { color: 'var(--muted)', title: '排队等待中' },
};

const TaskItem = memo(function TaskItem({ task, onDelete, onStopSeed, onRetry }) {
  const isBad = task.state === 'failed';
  const isSeed = task.state === 'seeding';
  const isQueued = task.state === 'queued';
  const dot = healthDot[task.health] || healthDot.poor;

  return (
    <div className={isBad ? 'task task-bad' : isSeed ? 'task task-seed' : 'task'}>
      <div className="task-head">
        <div className="task-title-wrap">
          <span className="task-health-dot" style={{ background: dot.color }} title={dot.title} />
          <b className="task-title" title={task.name}>{task.name}</b>
        </div>
        <div className="task-head-actions">
          {isBad && task.canRetry && (
            <Button variant="primary" size="sm" onClick={() => onRetry(task.id)}>重试</Button>
          )}
          {isSeed && (
            <Button className="seed-stop-btn" size="sm" onClick={() => onStopSeed(task.id)}>停止做种</Button>
          )}
          <Button size="sm" title="取消任务不会删除已下载分片" onClick={() => onDelete(task.id)}>{isBad ? '移除' : '取消'}</Button>
        </div>
      </div>
      <div className="task-line">
        <span className="task-state-text">{task.stateText || task.state}</span>
        {!isQueued && !isBad && (
          <span> · {isSeed ? task.downloadedText : `${task.downloadedText} / ${task.lengthText}`}</span>
        )}
      </div>
      {isSeed ? (
        <>
          <div className="task-line subtle">
            上传 <strong>{task.uploadSpeedText}</strong> · {task.peers} 个节点
          </div>
          <div className="task-line subtle">
            已上传 {task.seedUploadedText} · {task.seedTimeText} · 分享率 {task.ratioText}
          </div>
        </>
      ) : isQueued ? (
        <div className="task-line subtle">队列位置：第 {task.queuePosition || '?'} 位，当前任务完成后自动开始</div>
      ) : isBad ? (
        <div className="task-error">{task.error}</div>
      ) : (
        <div className="task-line subtle">
          <strong>{task.downloadSpeedText}</strong> · {task.peers} 个节点连接
        </div>
      )}
      {task.state !== 'queued' && task.state !== 'failed' && task.state !== 'done' && (
        <ProgressBar value={task.progress} />
      )}
    </div>
  );
});

export default TaskItem;
