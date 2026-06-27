import { memo, forwardRef } from 'react';

const Select = memo(forwardRef(function Select({
  value,
  onChange,
  children,
  className = '',
  ...props
}, ref) {
  return (
    <select
      ref={ref}
      className={`select ${className}`}
      value={value}
      onChange={onChange}
      {...props}
    >
      {children}
    </select>
  );
}));

export default Select;
