import MDXComponents from '@theme-original/MDXComponents';
import React from 'react';
import { CheckCircle2, AlertTriangle, XCircle, FlaskConical } from 'lucide-react';

export default {
  ...MDXComponents,
  IconCheck: () => (
    <CheckCircle2
      size={16}
      style={{
        color: '#22c55e',
        verticalAlign: 'middle',
        marginRight: '4px',
        display: 'inline-block',
      }}
    />
  ),
  IconAlert: () => (
    <AlertTriangle
      size={16}
      style={{
        color: '#eab308',
        verticalAlign: 'middle',
        marginRight: '4px',
        display: 'inline-block',
      }}
    />
  ),
  IconX: () => (
    <XCircle
      size={16}
      style={{
        color: '#ef4444',
        verticalAlign: 'middle',
        marginRight: '4px',
        display: 'inline-block',
      }}
    />
  ),
  IconFlask: () => (
    <FlaskConical
      size={16}
      style={{
        color: '#a855f7',
        verticalAlign: 'middle',
        marginRight: '4px',
        display: 'inline-block',
      }}
    />
  ),
};
