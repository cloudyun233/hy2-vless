import { memo } from 'react';
import { percent } from '../../utils/constants';

const ProgressBar = memo(function ProgressBar({ value = 0 }) {
  return (
    <div className="progress-bar">
      <div className="progress-fill" style={{ width: percent(value) }} />
    </div>
  );
});

export default ProgressBar;
