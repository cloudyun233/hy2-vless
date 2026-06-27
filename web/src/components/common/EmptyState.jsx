import { memo } from 'react';

const EmptyState = memo(function EmptyState({ icon = '🎬', message = '暂无内容' }) {
  return (
    <div className="empty-state" role="status">
      <div className="empty-icon">{icon}</div>
      <div className="empty-text">{message}</div>
    </div>
  );
});

export default EmptyState;
