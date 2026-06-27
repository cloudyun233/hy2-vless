import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import TopBar from './components/layout/TopBar';
import HeroPanel from './components/hero/HeroPanel';
import { StatsGrid } from './components/common/StatCard';
import VideoGrid from './components/video/VideoGrid';
import TaskList from './components/tasks/TaskList';
import RecentList from './components/tasks/RecentList';
import Input from './components/common/Input';
import Select from './components/common/Select';
import ConfirmDialog from './components/common/ConfirmDialog';
import { useToast } from './components/common/Toast';
import { requestJson } from './utils/api';
import { readLocal, writeLocal } from './utils/storage';
import {
  KEY_STORAGE,
  RECENT_STORAGE,
  PROGRESS_STORAGE,
  fileSignature,
  sortFiles,
} from './utils/constants';

const FAST_INTERVAL = 2000;
const NORMAL_INTERVAL = 5000;
const IDLE_INTERVAL = 12000;
const HIDDEN_INTERVAL = 30000;
const ERROR_BACKOFF_BASE = 1000;
const MAX_ERROR_BACKOFF = 15000;

export default function App() {
  const [accessKey, setAccessKey] = useState(() => readLocal(KEY_STORAGE, ''));
  const [magnet, setMagnet] = useState('');
  const [status, setStatus] = useState(null);
  const [files, setFiles] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [query, setQuery] = useState('');
  const [sortMode, setSortMode] = useState('latest');
  const [recentIds, setRecentIds] = useState(() => readLocal(RECENT_STORAGE, []));
  const [progressMap, setProgressMap] = useState(() => readLocal(PROGRESS_STORAGE, {}));
  const [loading, setLoading] = useState(true);
  const [confirmDialog, setConfirmDialog] = useState({ isOpen: false, fileId: null, taskId: null });
  const [activeSection, setActiveSection] = useState('library');
  const [message, setMessage] = useState(null);

  const toast = useToast();
  const fileSigRef = useRef('');
  const pendingFilesRef = useRef(null);
  const playingIdsRef = useRef(new Set());
  const progressWriteRef = useRef(0);
  const prevTaskStatesRef = useRef(new Map());
  const prevDoneNotifiedRef = useRef(new Set());

  useEffect(() => {
    if (accessKey.trim()) writeLocal(KEY_STORAGE, accessKey);
    else {
      try {
        window.localStorage.removeItem(KEY_STORAGE);
      } catch {}
    }
  }, [accessKey]);

  const authHeaders = useMemo(() => {
    const key = accessKey.trim();
    return key ? { 'X-Library-Key': key } : {};
  }, [accessKey]);

  const applyFiles = useCallback((nextFiles, force = false) => {
    const nextSig = fileSignature(nextFiles);
    if (!force && nextSig === fileSigRef.current) return;

    if (!force && playingIdsRef.current.size > 0) {
      pendingFilesRef.current = nextFiles;
      return;
    }

    fileSigRef.current = nextSig;
    pendingFilesRef.current = null;
    setFiles(nextFiles);
    setLoading(false);
  }, []);

  const flushPendingFiles = useCallback(() => {
    if (playingIdsRef.current.size > 0 || !pendingFilesRef.current) return;

    const nextFiles = pendingFilesRef.current;
    pendingFilesRef.current = null;
    fileSigRef.current = fileSignature(nextFiles);
    setFiles(nextFiles);
  }, []);

  const checkTaskTransitions = useCallback((newTasks) => {
    const newStates = new Map();
    const completed = [];
    const failed = [];

    for (const task of newTasks) {
      newStates.set(task.id, task.state);
      const prevState = prevTaskStatesRef.current.get(task.id);

      if (prevState && prevState !== 'done' && prevState !== 'seeding' && (task.state === 'done' || task.state === 'seeding')) {
        if (!prevDoneNotifiedRef.current.has(task.id)) {
          completed.push(task);
          prevDoneNotifiedRef.current.add(task.id);
        }
      }

      if (prevState && prevState !== 'failed' && task.state === 'failed') {
        failed.push(task);
      }
    }

    for (const task of completed) {
      toast.success(`《${task.name}》下载完成，可以观看了`, { duration: 6000 });
    }
    for (const task of failed) {
      toast.error(`《${task.name || task.id}》下载失败：${task.error || '未知错误'}`);
    }

    for (const [oldId] of prevTaskStatesRef.current) {
      if (!newStates.has(oldId) && !['done', 'seeding'].includes(prevTaskStatesRef.current.get(oldId))) {
        prevDoneNotifiedRef.current.delete(oldId);
      }
    }

    prevTaskStatesRef.current = newStates;
  }, [toast]);

  const refreshStatus = useCallback(async (forceFiles = false) => {
    try {
      const data = await requestJson('/api/status');
      setStatus(data);
      setTasks(data.torrents || []);
      checkTaskTransitions(data.torrents || []);
      applyFiles(data.files || [], forceFiles);

      if (!data.downloadEnabled) {
        setMessage({ text: `下载器不可用：${data.downloadError}`, bad: true });
      } else {
        setMessage(null);
      }
      setLoading(false);
    } catch (error) {
      setMessage({ text: `连接失败：${error.message}`, bad: true });
      setLoading(false);
    }
  }, [applyFiles, checkTaskTransitions]);

  useEffect(() => {
    let alive = true;
    let timer = null;
    let errorCount = 0;

    async function tick() {
      try {
        const data = await requestJson('/api/status');
        if (!alive) return;
        setStatus(data);
        setTasks(data.torrents || []);
        checkTaskTransitions(data.torrents || []);
        applyFiles(data.files || []);
        errorCount = 0;
        setLoading(false);

        if (!data.downloadEnabled) {
          setMessage({ text: `下载器不可用：${data.downloadError}`, bad: true });
        } else {
          setMessage(null);
        }
      } catch (error) {
        if (!alive) return;
        errorCount += 1;
        setMessage({ text: `连接失败：${error.message}`, bad: true });
        setLoading(false);
      }
    }

    function getInterval() {
      if (document.hidden) return HIDDEN_INTERVAL;
      if (errorCount > 0) {
        return Math.min(ERROR_BACKOFF_BASE * Math.pow(2, errorCount - 1), MAX_ERROR_BACKOFF);
      }
      const currentTasks = prevTaskStatesRef.current;
      let downloading = 0;
      for (const state of currentTasks.values()) {
        if (state === 'downloading') downloading += 1;
      }
      if (downloading > 0) return FAST_INTERVAL;
      if (currentTasks.size > 0) return NORMAL_INTERVAL;
      return IDLE_INTERVAL;
    }

    function schedule() {
      const interval = getInterval();
      timer = setTimeout(async () => {
        await tick();
        if (alive) {
          flushPendingFiles();
          schedule();
        }
      }, interval);
    }

    const handleVisibility = () => {
      if (!document.hidden) {
        clearTimeout(timer);
        tick();
        schedule();
      }
    };

    tick();
    schedule();
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      alive = false;
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [applyFiles, checkTaskTransitions, flushPendingFiles]);

  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.slice(1);
      if (hash === 'tasks' || hash === 'library') {
        setActiveSection(hash);
      }
    };
    handleHashChange();
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  const addMagnet = useCallback(async () => {
    const value = magnet.trim();
    if (!value) {
      toast.error('请粘贴磁力链接');
      return;
    }

    try {
      const data = await requestJson('/api/downloads', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: JSON.stringify({ magnet: value }),
      });
      setMagnet('');
      const torrentState = data?.torrent?.state;
      if (torrentState === 'queued') {
        toast.success('任务已加入队列');
      } else if (torrentState === 'downloading') {
        toast.success('任务已添加，开始下载');
      } else {
        toast.success('任务已添加');
      }
      await refreshStatus();
    } catch (error) {
      toast.error(error.message || '添加失败');
    }
  }, [authHeaders, magnet, refreshStatus, toast]);

  const retryTask = useCallback(async (id) => {
    try {
      await requestJson(`/api/downloads/${encodeURIComponent(id)}/retry`, {
        method: 'POST',
        headers: authHeaders,
      });
      toast.success('已重新开始下载');
      await refreshStatus();
    } catch (error) {
      toast.error(error.message || '重试失败');
    }
  }, [authHeaders, refreshStatus, toast]);

  const confirmDeleteTask = useCallback((id) => {
    setConfirmDialog({ isOpen: true, fileId: null, taskId: id });
  }, []);

  const deleteTask = useCallback(async () => {
    const id = confirmDialog.taskId;
    setConfirmDialog({ isOpen: false, fileId: null, taskId: null });
    if (!id) return;
    try {
      await requestJson(`/api/downloads/${encodeURIComponent(id)}`, {
        method: 'DELETE',
        headers: authHeaders,
      });
      prevDoneNotifiedRef.current.delete(id);
      toast.success('任务已移除');
      await refreshStatus();
    } catch (error) {
      toast.error(error.message || '移除失败');
    }
  }, [authHeaders, confirmDialog.taskId, refreshStatus, toast]);

  const stopSeeding = useCallback(async (id) => {
    try {
      await requestJson(`/api/seed/stop/${encodeURIComponent(id)}`, {
        method: 'POST',
        headers: authHeaders,
      });
      toast.success('已停止做种');
      await refreshStatus();
    } catch (error) {
      toast.error(error.message || '停止做种失败');
    }
  }, [authHeaders, refreshStatus, toast]);

  const confirmDeleteFile = useCallback((id) => {
    setConfirmDialog({ isOpen: true, fileId: id, taskId: null });
  }, []);

  const closeConfirmDialog = useCallback(() => {
    setConfirmDialog({ isOpen: false, fileId: null, taskId: null });
  }, []);

  const deleteFile = useCallback(async () => {
    const id = confirmDialog.fileId;
    setConfirmDialog({ isOpen: false, fileId: null, taskId: null });
    if (!id) return;

    try {
      await requestJson(`/api/files/${encodeURIComponent(id)}`, {
        method: 'DELETE',
        headers: authHeaders,
      });
      toast.success('文件已删除');
      await refreshStatus(true);
    } catch (error) {
      toast.error(error.message || '删除失败');
    }
  }, [authHeaders, confirmDialog.fileId, refreshStatus, toast]);

  const handlePlaybackChange = useCallback((id, playing) => {
    if (playing) {
      playingIdsRef.current.add(id);
      return;
    }

    playingIdsRef.current.delete(id);
    flushPendingFiles();
  }, [flushPendingFiles]);

  const handlePlayed = useCallback((id) => {
    setRecentIds((old) => {
      const next = [id, ...old.filter((item) => item !== id)].slice(0, 16);
      writeLocal(RECENT_STORAGE, next);
      return next;
    });
  }, []);

  const handleProgress = useCallback((id, time, duration) => {
    if (!Number.isFinite(time) || !Number.isFinite(duration) || duration <= 0) return;
    const now = Date.now();
    if (now - progressWriteRef.current < 1500) return;
    progressWriteRef.current = now;

    setProgressMap((old) => {
      const next = { ...old, [id]: { time, duration, updatedAt: now } };
      writeLocal(PROGRESS_STORAGE, next);
      return next;
    });
  }, []);

  const clearLocalHistory = useCallback(() => {
    setRecentIds([]);
    setProgressMap({});
    writeLocal(RECENT_STORAGE, []);
    writeLocal(PROGRESS_STORAGE, {});
    toast.info('记录已清空');
  }, [toast]);

  const handlePlaybackError = useCallback((text) => {
    toast.error(text);
  }, [toast]);

  const visibleFiles = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const filtered = needle
      ? files.filter((file) => `${file.name} ${file.rel || ''}`.toLowerCase().includes(needle))
      : files;
    return sortFiles(filtered, sortMode, recentIds);
  }, [files, query, recentIds, sortMode]);

  const space = status?.space || {};
  const visitors = status?.visitors || {};
  const summary = status?.summary || {};
  const activeTasks = summary.downloadingCount ?? tasks.filter((task) => task.state === 'downloading').length;
  const queuedTasks = summary.queuedCount ?? tasks.filter((task) => task.state === 'queued').length;
  const failedTasks = summary.failedCount ?? tasks.filter((task) => task.state === 'failed').length;
  const seedingTasks = summary.seedingCount ?? tasks.filter((task) => task.state === 'seeding').length;
  const totalSpeed = summary.totalDownloadSpeedText || '0 B/s';
  const totalUpload = summary.totalUploadSpeedText || '0 B/s';

  return (
    <main className="page">
      <TopBar visitorCount={visitors.weeklyVisitors} activeSection={activeSection} />

      <HeroPanel
        magnet={magnet}
        onMagnetChange={setMagnet}
        onAddMagnet={addMagnet}
        accessKey={accessKey}
        onAccessKeyChange={setAccessKey}
        message={message}
        downloadAuthRequired={!!status?.downloadAuthRequired}
      />

      <StatsGrid
        summary={summary}
        space={space}
        trackers={status?.trackers}
        totalSpeed={totalSpeed}
        totalUpload={totalUpload}
        activeTasks={activeTasks}
        queuedTasks={queuedTasks}
        seedingTasks={seedingTasks}
        failedTasks={failedTasks}
      />

      <section className="app-layout">
        <section className="library" id="library">
          <div className="section-head">
            <div>
              <p>Library</p>
              <h2>片库</h2>
            </div>
            <div className="tools">
              <Input
                className="search-input"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="搜索片名"
                aria-label="搜索影片"
              />
              <Select value={sortMode} onChange={(event) => setSortMode(event.target.value)} aria-label="排序方式">
                <option value="latest">最新</option>
                <option value="recent">最近播放</option>
                <option value="name">名称</option>
                <option value="size">大小</option>
              </Select>
            </div>
          </div>

          <VideoGrid
            files={visibleFiles}
            loading={loading}
            progressMap={progressMap}
            recentIds={recentIds}
            onDelete={confirmDeleteFile}
            onPlayed={handlePlayed}
            onPlaybackChange={handlePlaybackChange}
            onPlaybackError={handlePlaybackError}
            onProgress={handleProgress}
          />
        </section>

        <aside className="side-rail" id="tasks">
          <section className="rail-section">
            <div className="rail-head">
              <h2>任务</h2>
              <span>{tasks.length}</span>
            </div>
            <TaskList tasks={tasks} onDelete={confirmDeleteTask} onStopSeed={stopSeeding} onRetry={retryTask} />
          </section>

          <RecentList
            recentIds={recentIds}
            files={files}
            progressMap={progressMap}
            onClear={clearLocalHistory}
          />
        </aside>
      </section>

      <ConfirmDialog
        isOpen={confirmDialog.isOpen}
        title={confirmDialog.taskId ? '取消任务' : '删除影片'}
        message={confirmDialog.taskId ? '确认取消这个任务？取消任务不会删除已下载分片。' : '确认删除这个影片文件？此操作不可撤销。'}
        confirmText={confirmDialog.taskId ? '取消任务' : '删除'}
        cancelText="取消"
        onConfirm={confirmDialog.taskId ? deleteTask : deleteFile}
        onCancel={closeConfirmDialog}
      />
    </main>
  );
}
