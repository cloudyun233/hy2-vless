import { memo, useEffect, useState } from 'react';
import Input from '../common/Input';
import Button from '../common/Button';

const MAGNET_REGEX = /^magnet:\?xt=urn:btih:/i;

function validateMagnet(value) {
  const trimmed = value.trim();
  if (!trimmed) return { valid: null, message: '' };
  if (MAGNET_REGEX.test(trimmed)) return { valid: true, message: '链接格式正确' };
  return { valid: false, message: '请输入有效的磁力链接（magnet:?xt=urn:btih:...）' };
}

const HeroPanel = memo(function HeroPanel({
  magnet,
  onMagnetChange,
  onAddMagnet,
  accessKey,
  onAccessKeyChange,
  message,
  downloadAuthRequired,
}) {
  const [validation, setValidation] = useState({ valid: null, message: '' });

  useEffect(() => {
    setValidation(validateMagnet(magnet));
  }, [magnet]);

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && validation.valid) onAddMagnet();
  };

  const handlePasteClick = async () => {
    try {
      const text = await navigator.clipboard.readText();
      const first = text.split(/\r?\n/).find((line) => MAGNET_REGEX.test(line.trim()));
      if (first) {
        onMagnetChange(first.trim());
      }
    } catch {}
  };

  return (
    <section className="hero-panel">
      <div className="hero-copy">
        <p>Moonroom</p>
        <h1>月光放映室</h1>
      </div>

      <div className="command-panel">
        <div className="magnet-row">
          <Input
            className={`magnet-input ${validation.valid === false ? 'input-error' : ''} ${validation.valid ? 'input-valid' : ''}`}
            value={magnet}
            onChange={(e) => {
              onMagnetChange(e.target.value);
            }}
            onKeyDown={handleKeyDown}
            placeholder="magnet:?xt=urn:btih:..."
            aria-label="磁力链接输入"
            aria-invalid={validation.valid === false}
          />
          <Button variant="primary" onClick={onAddMagnet} disabled={!validation.valid}>
            开始下载
          </Button>
        </div>
        {validation.valid === false && (
          <div className="input-hint input-hint-error">{validation.message}</div>
        )}
        <button type="button" className="paste-hint" onClick={handlePasteClick}>
          粘贴磁力链接
        </button>
        {downloadAuthRequired && !accessKey.trim() && (
          <div className="input-hint">下载需要访问密钥</div>
        )}
        <div className="key-row">
          <Input
            type="password"
            value={accessKey}
            onChange={(e) => onAccessKeyChange(e.target.value)}
            placeholder="访问密钥"
            aria-label="访问密钥"
          />
          {message?.text ? (
            <div className={`message ${message?.bad ? 'error' : message?.success ? 'success' : ''}`}>
              {message.text}
            </div>
          ) : null}
        </div>
      </div>
    </section>
  );
});

export default HeroPanel;
