import { memo } from 'react';

const Skeleton = memo(function Skeleton({ width, height, style, className = '' }) {
  return (
    <div
      className={`skeleton ${className}`}
      style={{ width, height, ...style }}
      aria-hidden="true"
    />
  );
});

export const VideoCardSkeleton = memo(function VideoCardSkeleton() {
  return (
    <div className="video-card" aria-hidden="true">
      <div className="poster-shell">
        <Skeleton width="100%" height="100%" />
      </div>
      <div className="meta">
        <Skeleton width="80%" height={16} style={{ marginBottom: 8 }} />
        <Skeleton width="50%" height={12} style={{ marginBottom: 12 }} />
        <div className="card-actions">
          <Skeleton width={40} height={12} />
          <Skeleton width={50} height={28} />
        </div>
      </div>
    </div>
  );
});

export const StatCardSkeleton = memo(function StatCardSkeleton() {
  return (
    <div className="stat-card" aria-hidden="true">
      <Skeleton width={60} height={12} style={{ marginBottom: 8 }} />
      <Skeleton width="70%" height={24} style={{ marginBottom: 4 }} />
      <Skeleton width="50%" height={12} />
    </div>
  );
});

export default Skeleton;
