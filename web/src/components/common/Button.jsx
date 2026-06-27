import { memo, forwardRef } from 'react';

const Button = memo(forwardRef(function Button({
  children,
  variant = 'ghost',
  size = 'md',
  type = 'button',
  onClick,
  className = '',
  disabled = false,
  ...props
}, ref) {
  const variantClass = variant === 'primary' ? 'btn-primary' : variant === 'danger' ? 'btn-ghost btn-danger' : 'btn-ghost';
  const sizeStyle = size === 'sm' ? { minHeight: 30, padding: '0 10px', fontSize: 13 } : {};

  return (
    <button
      ref={ref}
      type={type}
      className={`${variantClass} ${className}`}
      onClick={onClick}
      disabled={disabled}
      style={sizeStyle}
      {...props}
    >
      {children}
    </button>
  );
}));

export default Button;
