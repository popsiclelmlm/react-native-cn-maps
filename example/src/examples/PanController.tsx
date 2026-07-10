import { useRef } from 'react';

import { View, Animated, PanResponder } from 'react-native';

function PanController(props: any) {
  // 每次渲染同步最新 props，供只创建一次的 PanResponder 回调闭包读取
  const propsRef = useRef(props);
  propsRef.current = props;

  // 原实例字段：可变、非渲染状态，用 ref 承载
  const directionRef = useRef<any>(null);
  const listenerRef = useRef<any>(null);
  // 原 constructor 里按 momentumDecayConfig 计算一次 deceleration（保持 truthy 判断语义）
  const decelerationRef = useRef<any>(
    props.momentumDecayConfig && props.momentumDecayConfig.deceleration
      ? props.momentumDecayConfig.deceleration
      : 0.997
  );

  function handleResponderMove(
    anim: any,
    delta: any,
    min: any,
    max: any,
    overshoot: any
  ) {
    let val = anim._offset + delta;

    if (val > max) {
      switch (overshoot) {
        case 'spring':
          val = max + (val - max) / propsRef.current.overshootReductionFactor;
          break;
        case 'clamp':
          val = max;
          break;
      }
    }
    if (val < min) {
      switch (overshoot) {
        case 'spring':
          val = min - (min - val) / propsRef.current.overshootReductionFactor;
          break;
        case 'clamp':
          val = min;
          break;
      }
    }
    val = val - anim._offset;
    anim.setValue(val);
  }

  function handleResponderRelease(
    anim: any,
    min: any,
    max: any,
    velocity: any,
    overshoot: any,
    mode: any,
    snapSpacing: any
  ) {
    anim.flattenOffset();

    if (anim._value < min) {
      if (propsRef.current.onOvershoot) {
        propsRef.current.onOvershoot(); // TODO: 这里应该传入什么参数
      }
      switch (overshoot) {
        case 'spring':
          Animated.spring(anim, {
            ...propsRef.current.overshootSpringConfig,
            toValue: min,
            velocity,
          }).start();
          break;
        case 'clamp':
          anim.setValue(min);
          break;
      }
    } else if (anim._value > max) {
      if (propsRef.current.onOvershoot) {
        propsRef.current.onOvershoot(); // TODO: 这里应该传入什么参数
      }
      switch (overshoot) {
        case 'spring':
          Animated.spring(anim, {
            ...propsRef.current.overshootSpringConfig,
            toValue: max,
            velocity,
          }).start();
          break;
        case 'clamp':
          anim.setValue(min);
          break;
      }
    } else {
      switch (mode) {
        case 'snap':
          handleSnappedScroll(anim, min, max, velocity, snapSpacing);
          break;

        case 'decay':
          handleMomentumScroll(anim, min, max, velocity, overshoot);
          break;

        case 'spring-origin':
          Animated.spring(anim, {
            ...propsRef.current.springOriginConfig,
            toValue: 0,
            velocity,
          }).start();
          break;
      }
    }
  }

  function handleResponderGrant(anim: any, mode: any) {
    switch (mode) {
      case 'spring-origin':
        anim.setValue(0);
        break;
      case 'snap':
      case 'decay':
        anim.setOffset(anim._value + anim._offset);
        anim.setValue(0);
        break;
    }
  }

  function handleMomentumScroll(
    anim: any,
    min: any,
    max: any,
    velocity: any,
    overshoot: any
  ) {
    Animated.decay(anim, {
      ...propsRef.current.momentumDecayConfig,
      velocity,
    }).start(() => {
      anim.removeListener(listenerRef.current);
    });

    listenerRef.current = anim.addListener(({ value }: any) => {
      if (value < min) {
        anim.removeListener(listenerRef.current);
        if (propsRef.current.onOvershoot) {
          propsRef.current.onOvershoot(); // TODO: 这里应该传入什么参数
        }
        switch (overshoot) {
          case 'spring':
            Animated.spring(anim, {
              ...propsRef.current.overshootSpringConfig,
              toValue: min,
              velocity,
            }).start();
            break;
          case 'clamp':
            anim.setValue(min);
            break;
        }
      } else if (value > max) {
        anim.removeListener(listenerRef.current);
        if (propsRef.current.onOvershoot) {
          propsRef.current.onOvershoot(); // TODO: 这里应该传入什么参数
        }
        switch (overshoot) {
          case 'spring':
            Animated.spring(anim, {
              ...propsRef.current.overshootSpringConfig,
              toValue: max,
              velocity,
            }).start();
            break;
          case 'clamp':
            anim.setValue(min);
            break;
        }
      }
    });
  }

  function handleSnappedScroll(
    anim: any,
    min: any,
    max: any,
    velocity: any,
    spacing: any
  ) {
    let endX = momentumCenter(anim._value, velocity, spacing);
    endX = Math.max(endX, min);
    endX = Math.min(endX, max);
    const bounds = [endX - spacing / 2, endX + spacing / 2];
    const endV = velocityAtBounds(anim._value, velocity, bounds);

    listenerRef.current = anim.addListener(({ value }: any) => {
      if (value > bounds[0] && value < bounds[1]) {
        Animated.spring(anim, {
          toValue: endX,
          velocity: endV,
          useNativeDriver: false,
        }).start();
      }
    });

    Animated.decay(anim, {
      ...propsRef.current.momentumDecayConfig,
      velocity,
    }).start(() => {
      anim.removeListener(listenerRef.current);
    });
  }

  function closestCenter(x: any, spacing: any) {
    const plus = x % spacing < spacing / 2 ? 0 : spacing;
    return Math.round(x / spacing) * spacing + plus;
  }

  function momentumCenter(x0: any, vx: any, spacing: any) {
    let t = 0;
    let x1 = x0;
    let x = x1;

    while (true) {
      t += 16;
      x =
        x0 +
        (vx / (1 - decelerationRef.current)) *
          (1 - Math.exp(-(1 - decelerationRef.current) * t));
      if (Math.abs(x - x1) < 0.1) {
        x1 = x;
        break;
      }
      x1 = x;
    }
    return closestCenter(x1, spacing);
  }

  function velocityAtBounds(x0: any, vx: any, bounds: any) {
    let t = 0;
    let x1 = x0;
    let x = x1;
    let vf;
    while (true) {
      t += 16;
      x =
        x0 +
        (vx / (1 - decelerationRef.current)) *
          (1 - Math.exp(-(1 - decelerationRef.current) * t));
      vf = (x - x1) / 16;
      if (x > bounds[0] && x < bounds[1]) {
        break;
      }
      if (Math.abs(vf) < 0.1) {
        break;
      }
      x1 = x;
    }
    return vf;
  }

  // PanResponder 只创建一次（存进 ref），回调里一律用 propsRef.current 取最新 props
  const responder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: props.onStartShouldSetPanResponder,
      onMoveShouldSetPanResponder: props.onMoveShouldSetPanResponder,
      onPanResponderGrant: (...args) => {
        if (propsRef.current.onPanResponderGrant) {
          propsRef.current.onPanResponderGrant(...args);
        }
        let { panX, panY, horizontal, vertical, xMode, yMode } =
          propsRef.current;

        handleResponderGrant(panX, xMode);
        handleResponderGrant(panY, yMode);

        directionRef.current =
          horizontal && !vertical ? 'x' : vertical && !horizontal ? 'y' : null;
      },

      onPanResponderMove: (_, { dx, dy, x0, y0 }) => {
        let {
          panX,
          panY,
          xBounds,
          yBounds,
          overshootX,
          overshootY,
          horizontal,
          vertical,
          lockDirection,
          directionLockDistance,
        } = propsRef.current;

        if (!directionRef.current) {
          const dx2 = dx * dx;
          const dy2 = dy * dy;
          if (dx2 + dy2 > directionLockDistance) {
            directionRef.current = dx2 > dy2 ? 'x' : 'y';
            if (propsRef.current.onDirectionChange) {
              propsRef.current.onDirectionChange(directionRef.current, {
                dx,
                dy,
                x0,
                y0,
              });
            }
          }
        }

        const dir = directionRef.current;

        if (propsRef.current.onPanResponderMove) {
          propsRef.current.onPanResponderMove(_, { dx, dy, x0, y0 });
        }

        if (horizontal && (!lockDirection || dir === 'x')) {
          let [xMin, xMax] = xBounds;

          handleResponderMove(panX, dx, xMin, xMax, overshootX);
        }

        if (vertical && (!lockDirection || dir === 'y')) {
          let [yMin, yMax] = yBounds;

          handleResponderMove(panY, dy, yMin, yMax, overshootY);
        }
      },

      onPanResponderRelease: (_, { vx, vy, dx, dy }) => {
        let {
          panX,
          panY,
          xBounds,
          yBounds,
          overshootX,
          overshootY,
          horizontal,
          vertical,
          lockDirection,
          xMode,
          yMode,
          snapSpacingX,
          snapSpacingY,
        } = propsRef.current;

        let cancel = false;

        const dir = directionRef.current;

        if (propsRef.current.onRelease) {
          cancel = propsRef.current.onRelease({ vx, vy, dx, dy }) === false;
        }

        if (!cancel && horizontal && (!lockDirection || dir === 'x')) {
          let [xMin, xMax] = xBounds;
          if (propsRef.current.onReleaseX) {
            cancel = propsRef.current.onReleaseX({ vx, vy, dx, dy }) === false;
          }
          !cancel &&
            handleResponderRelease(
              panX,
              xMin,
              xMax,
              vx,
              overshootX,
              xMode,
              snapSpacingX
            );
        }

        if (!cancel && vertical && (!lockDirection || dir === 'y')) {
          let [yMin, yMax] = yBounds;
          if (propsRef.current.onReleaseY) {
            cancel = propsRef.current.onReleaseY({ vx, vy, dx, dy }) === false;
          }
          !cancel &&
            handleResponderRelease(
              panY,
              yMin,
              yMax,
              vy,
              overshootY,
              yMode,
              snapSpacingY
            );
        }

        directionRef.current =
          horizontal && !vertical ? 'x' : vertical && !horizontal ? 'y' : null;
      },
    })
  ).current;

  return <View {...props} {...responder.panHandlers} />;
}

export default PanController;
