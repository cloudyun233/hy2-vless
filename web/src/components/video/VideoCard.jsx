import { memo, useCallback, useRef } from 'react';
import { serverAsset, progressLabel } from '../../utils/constants';
import Button from '../common/Button';

const PlayIcon = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M8 5v14l11-7z" />
  </svg>
);

const VideoCard = memo(function VideoCard({
  file,
  progressMap,
  recentIds,
  onDelete,
  onPlayed,
  onPlaybackChange,
  onPlaybackError,
  onProgress,
  index = 0,
}) {
  const videoRef = useRef(null);
  const loadedRef = useRef(false);
  const savedProgress = progressMap[file.id];
  const isRecent = recentIds.includes(file.id);

  const loadMedia = useCallback(() => {
    const video = videoRef.current;
    if (!video || loadedRef.current) return video;
    video.src = serverAsset(file.url);
    video.load();
    loadedRef.current = true;
    return video;
  }, [file.url]);

  const play = useCallback(async () => {
    const video = loadMedia();
    if (!video) return;
    try {
      await video.play();
    } catch (error) {
      if (error?.name === 'AbortError') return;
      if (error?.name === 'NotSupportedError') {
        onPlaybackError('该视频格式不支持播放');
      } else {
        onPlaybackError('视频加载失败，请检查网络');
      }
    }
  }, [loadMedia, onPlaybackError]);

  const progress = savedProgress ? (savedProgress.time / savedProgress.duration) * 100 : 0;

  return (
    <article
      className="video-card"
      style={{ animationDelay: `${Math.min(index * 0.03, 0.3)}s` }}
    >
      <div className="poster-shell">
        <video
          ref={videoRef}
          preload="none"
          poster={serverAsset(file.thumbUrl)}
          controls
          playsInline
          onLoadedMetadata={(event) => {
            if (savedProgress?.time && savedProgress.time < event.currentTarget.duration - 8) {
              event.currentTarget.currentTime = savedProgress.time;
            }
          }}
          onPointerDownCapture={loadMedia}
          onPlay={() => {
            loadMedia();
            onPlayed(file.id);
            onPlaybackChange(file.id, true);
          }}
          onPause={() => onPlaybackChange(file.id, false)}
          onEnded={() => onPlaybackChange(file.id, false)}
          onTimeUpdate={(event) => onProgress(file.id, event.currentTarget.currentTime, event.currentTarget.duration)}
        />
        <button
          className="play-btn"
          type="button"
          onClick={play}
          aria-label={`播放 ${file.name}`}
        >
          <PlayIcon />
        </button>
        {isRecent ? <span className="badge">最近</span> : null}
        {progress > 0 && (
          <div className="card-progress" aria-hidden="true">
            <div className="card-progress-fill" style={{ width: `${progress}%` }} />
          </div>
        )}
      </div>

      <div className="meta">
        <div className="video-title" title={file.name}>{file.name}</div>
        <div className="subtle">{file.sizeText} · {file.mtime}</div>
        <div className="card-actions">
          <span>{progressLabel(savedProgress) || file.type}</span>
          <Button variant="danger" size="sm" onClick={() => onDelete(file.id)}>删除</Button>
        </div>
      </div>
    </article>
  );
});

export default VideoCard;
