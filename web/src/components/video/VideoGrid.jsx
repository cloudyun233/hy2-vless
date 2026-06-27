import { memo } from 'react';
import VideoCard from './VideoCard';
import EmptyState from '../common/EmptyState';
import { VideoCardSkeleton } from '../common/Skeleton';

const VideoGrid = memo(function VideoGrid({ files, loading, progressMap, recentIds, ...cardProps }) {
  if (loading) {
    return (
      <div className="video-grid">
        {Array.from({ length: 8 }).map((_, i) => (
          <VideoCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (!files.length) {
    return (
      <div className="video-grid" style={{ display: 'block' }}>
        <EmptyState icon="🎬" message="暂无影片。粘贴磁力链接开始下载吧~" />
      </div>
    );
  }

  return (
    <div className="video-grid">
      {files.map((file, index) => (
        <VideoCard
          key={file.id}
          file={file}
          index={index}
          progressMap={progressMap}
          recentIds={recentIds}
          {...cardProps}
        />
      ))}
    </div>
  );
});

export default VideoGrid;
