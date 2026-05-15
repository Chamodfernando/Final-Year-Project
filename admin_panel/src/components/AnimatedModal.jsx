import { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion as Motion } from 'framer-motion';

/**
 * Full-screen dimmed overlay with animated panel (portal to document.body).
 */
export function AnimatedModal({
  open,
  onClose,
  children,
  panelClassName = '',
  ariaLabel,
  closeOnEscape = true,
  closeOnBackdrop = true,
  onExitComplete,
}) {
  useEffect(() => {
    if (!open || !closeOnEscape) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape') onClose?.();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose, closeOnEscape]);

  useEffect(() => {
    if (!open) return undefined;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  const handleBackdropPointerDown = (e) => {
    if (closeOnBackdrop && e.target === e.currentTarget) {
      onClose?.();
    }
  };

  const tree = (
    <AnimatePresence onExitComplete={onExitComplete}>
      {open && (
        <Motion.div
          key="animated-modal-root"
          className="animated-modal-backdrop"
          role="presentation"
          initial={{ opacity: 0 }}
          animate={{
            opacity: 1,
            transition: { duration: 0.22, ease: [0.16, 1, 0.3, 1] },
          }}
          exit={{
            opacity: 0,
            transition: { duration: 0.18, ease: [0.4, 0, 1, 1] },
          }}
          onPointerDown={handleBackdropPointerDown}
        >
          <Motion.div
            className={`animated-modal-surface ${panelClassName}`.trim()}
            role="dialog"
            aria-modal="true"
            aria-label={ariaLabel}
            initial={{ opacity: 0, scale: 0.92, y: 28 }}
            animate={{
              opacity: 1,
              scale: 1,
              y: 0,
              transition: { type: 'spring', stiffness: 420, damping: 32 },
            }}
            exit={{
              opacity: 0,
              scale: 0.94,
              y: 18,
              transition: { duration: 0.2, ease: [0.4, 0, 1, 1] },
            }}
            onPointerDown={(e) => e.stopPropagation()}
          >
            {children}
          </Motion.div>
        </Motion.div>
      )}
    </AnimatePresence>
  );

  if (typeof document === 'undefined') return null;
  return createPortal(tree, document.body);
}
