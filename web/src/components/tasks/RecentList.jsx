import { memo } from 'react';
import Button from '../common/Button';
import EmptyState from '../common/EmptyState';
import { progressLabel } from '../../utils/constants';

const RecentList = memo(function RecentList({ recentIds, files, progressMap, onClear }) {
  return (
    <section className="rail-section">
      <div className="rail-head">
        <h2>记录</h2>
        <Button size="sm" onClick={onClear}>清空</Button>
      </div>
      {recentIds.length ? recentIds.slice(0, 5).map((id) => {
        const file = files.find((item) => item.id === id);
        return (
          <div className="recent-item" key={id}>
            <span>{file?.name || '已删除'}</span>
            <b>{progressLabel(progressMap[id]) || '—'}</b>
          </div>
        );
      }) : <EmptyState icon="📖" message="暂无记录。" />}
    </section>
  );
});

export default RecentList;
