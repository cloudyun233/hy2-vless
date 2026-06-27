import { memo } from 'react';
import { percent } from '../../utils/constants';

const statIcons = {
  videos: '🎬',
  tasks: '📥',
  download: '⬇️',
  upload: '⬆️',
  space: '💾',
};

const StatCard = memo(function StatCard({ icon, label, value, detail, progress }) {
  return (
    <div className="stat-card">
      <div className="stat-header">
        <span className="stat-icon" aria-hidden="true">{icon}</span>
        <span>{label}</span>
      </div>
      <b>{value}</b>
      {detail ? <em>{detail}</em> : null}
      {progress != null && (
        <div className="progress-bar">
          <div className="progress-fill" style={{ width: percent(progress) }} />
        </div>
      )}
    </div>
  );
});

export const StatsGrid = memo(function StatsGrid({ summary, space, trackers, totalSpeed, totalUpload, activeTasks, queuedTasks, seedingTasks, failedTasks }) {
  return (
    <section className="stats-grid">
      <StatCard
        icon={statIcons.videos}
        label="影片"
        value={summary.fileCount ?? '—'}
        detail={space.libraryText || '—'}
      />
      <StatCard
        icon={statIcons.tasks}
        label="任务"
        value={`${activeTasks} / ${queuedTasks}`}
        detail={`${seedingTasks} 做种 · ${failedTasks} 失败`}
      />
      <StatCard
        icon={statIcons.download}
        label="下载"
        value={totalSpeed}
      />
      <StatCard
        icon={statIcons.upload}
        label="上传"
        value={totalUpload}
        detail={`${trackers ?? '—'} tracker`}
      />
      <StatCard
        icon={statIcons.space}
        label="空间"
        value={space.availableText || '—'}
        detail={`${space.usedText || '—'} / ${space.totalText || '—'}`}
        progress={space.usedPct}
      />
    </section>
  );
});

export default StatCard;
