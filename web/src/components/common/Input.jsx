import { memo, forwardRef } from 'react';

const Input = memo(forwardRef(function Input({
  value,
  onChange,
  onKeyDown,
  placeholder,
  type = 'text',
  className = '',
  ...props
}, ref) {
  return (
    <input
      ref={ref}
      type={type}
      className={`input ${className}`}
      value={value}
      onChange={onChange}
      onKeyDown={onKeyDown}
      placeholder={placeholder}
      {...props}
    />
  );
}));

export default Input;
