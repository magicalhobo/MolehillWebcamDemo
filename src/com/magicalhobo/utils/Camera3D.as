package com.magicalhobo.utils
{
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	
	public class Camera3D
	{
		private const DEGREES_TO_RADIANS:Number = Math.PI / 360.0;
		
		private var farClip:Number;
		private var fieldOfView:Number;
		private var nearClip:Number;
		
		private var projectionMatrix:Matrix3D;
		private var aspectRatio:Number = 1;
		
		public var position:Vector3D;
		public var target:Vector3D;
		
		public function Camera3D(nearClip:Number = 0.2, farClip:Number = 1000, fieldOfView:Number = 60)
		{
			this.nearClip = nearClip;
			this.farClip = farClip;
			this.fieldOfView = fieldOfView;
			
			position = new Vector3D();
			target = new Vector3D();
			
			updateProjectionMatrix();
		}
		
		public function getMatrix():Matrix3D
		{
			var viewMatrix:Matrix3D = getViewMatrix();
			viewMatrix.invert();
			viewMatrix.append(projectionMatrix);
			return viewMatrix;
		}
		
		protected function getViewMatrix():Matrix3D
		{
			var v:Vector3D = position.subtract(target);
			
			var zVector:Vector3D = v;
			var upVector:Vector3D = new Vector3D(0.0, 1.0, 0.0);
			
			var xVector:Vector3D = upVector.crossProduct(zVector);
			var yVector:Vector3D = zVector.crossProduct(xVector);
			
			xVector.normalize();
			yVector.normalize();
			zVector.normalize();
			
			var result:Matrix3D = new Matrix3D(
				Vector.<Number>([
					xVector.x, xVector.y, xVector.z, 0.0,
					yVector.x, yVector.y, yVector.z, 0.0,
					zVector.x, zVector.y, zVector.z, 0.0,
					position.x, position.y, position.z, 1.0
				])
			);
			
			return result
		}
		
		protected function updateProjectionMatrix():void
		{
			var ratio:Number = nearClip * Math.tan(fieldOfView * DEGREES_TO_RADIANS);
			
			var depth:Number = nearClip - farClip;
			var nearOverRatio:Number = nearClip/ratio;
			
			projectionMatrix = new Matrix3D(
				Vector.<Number>(
					[
						nearOverRatio,	0,				0,								0,
						0,				nearOverRatio,	0,								0,
						0,				0,				(farClip + nearClip)/depth,		-1,
						0,				0,				(2 * farClip * nearClip)/depth,	0
					]
				)
			);
		}
	}
}