using UnityEngine;

/// <summary>
/// Simple camera follow to track a target (player) with position smoothing and a configurable offset.
/// </summary>
public class PlayerCameraFollower : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset = new Vector3(0f, 200f, -200f);
    [SerializeField] private float smoothing = 5f;

    private void LateUpdate()
    {
        if (target == null)
        {
            return;
        }

        var desiredPosition = target.position + offset;
        transform.position = Vector3.Lerp(transform.position, desiredPosition, Mathf.Clamp01(smoothing * Time.deltaTime));
        transform.LookAt(target);
    }

    public void SetTarget(Transform t)
    {
        target = t;
    }

    public void SetOffset(Vector3 newOffset)
    {
        offset = newOffset;
    }

    public void SetSmoothing(float value)
    {
        smoothing = Mathf.Max(0.01f, value);
    }

    public void SnapToTarget()
    {
        if (target == null)
        {
            return;
        }

        transform.position = target.position + offset;
        transform.LookAt(target);
    }
}
