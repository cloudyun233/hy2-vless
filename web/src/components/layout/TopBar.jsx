import { memo, useEffect, useState } from 'react';

const TopBar = memo(function TopBar({ visitorCount, activeSection = 'library' }) {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header className={`topbar ${scrolled ? 'scrolled' : ''}`}>
      <a className="brand" href="#library" aria-label="Moonroom 月光放映室">
        <span className="brand-mark">M</span>
        <span>
          <strong>Moonroom</strong>
          <small>Private Cinema</small>
        </span>
      </a>
      <nav className="nav" aria-label="主导航">
        <a href="#library" className={activeSection === 'library' ? 'active' : ''}>片库</a>
        <a href="#tasks" className={activeSection === 'tasks' ? 'active' : ''}>任务</a>
      </nav>
      <div className="visitor-pill" title="本周访问人数">本周 {visitorCount ?? '—'}</div>
    </header>
  );
});

export default TopBar;
