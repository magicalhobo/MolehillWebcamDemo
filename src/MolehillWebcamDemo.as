package
{
	import com.adobe.*;
	import com.adobe.utils.AGALMiniAssembler;
	import com.magicalhobo.utils.Camera3D;
	
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.events.ActivityEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	[SWF(frameRate="60")]
	
	public class MolehillWebcamDemo extends Sprite
	{
		private var context3D:Context3D;
		private var indexBuffer:IndexBuffer3D;
		private var stage3D:Stage3D;
		private var program:Program3D;
		
		private var originalWidth:uint;
		private var originalHeight:uint;
		
		private var camera:Camera;
		private var video:Video;
		private var camera3D:Camera3D;
		
		private var texture:Texture;
		private var snapshot:BitmapData;
		private var snapshotTransform:Matrix;
		private var cameraDistance:int = 5;
		
		public function MolehillWebcamDemo()
		{
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			originalWidth = stage.stageWidth;
			originalHeight = stage.stageHeight;
			
			camera = Camera.getCamera();
			camera.setMode(1280, 960, 60);
			camera.addEventListener(ActivityEvent.ACTIVITY, activityHandler);
			
			video = new Video(1280, 960);
			video.smoothing = true;
			
			video.attachCamera(camera);
		}
		
		protected function activityHandler(ev:ActivityEvent):void
		{
			camera.removeEventListener(ActivityEvent.ACTIVITY, activityHandler);
			
			setup3D();
		}
		
		protected function setup3D():void
		{
			camera3D = new Camera3D();
			
			snapshot = new BitmapData(512, 512, false, 0xFF0000);
			
			snapshotTransform = new Matrix();
			snapshotTransform.scale(512/video.width, 512/video.height);
			
			stage3D = stage.stage3Ds[0];
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, context3DCreateHandler);
			stage3D.requestContext3D(); 
		}
		
		protected function createShader(type:String, opcodes:Array):ByteArray
		{
			var assembler:AGALMiniAssembler = new AGALMiniAssembler();
			assembler.assemble(type, opcodes.join('\n'));
			return assembler.agalcode;
		}
		
		protected function createPlane(context3D:Context3D, countX:int, countY:int):IndexBuffer3D
		{
			var vertexData:Vector.<Number> = new Vector.<Number>();
			
			var vertexCount:int = countX * countY;
			
			var diff:Number = 1/countX;
			for(var i1:int = 0; i1 < countX; i1++)
			{
				for(var i2:int = 0; i2 < countY; i2++)
				{
					var rand:Number = (Math.random() - 0.5) * diff;
					vertexData.push((2*i1/(countX - 1)) - 1, (2*i2/(countY - 1)) - 1, Math.pow(i1/countX, 2),  i1/(countX - 1), 1 - i2/(countY - 1));
				}
			}
			
			var indexData:Vector.<uint> = new Vector.<uint>();
			
			var indexCount:int = (countX - 1) * (countY - 1) * 6;
			
			for(var j1:int = 0; j1 < indexCount; j1++)
			{
				if(j1 % countX < countX - 1)
				{
					indexData.push(j1, j1 + 1, j1 + countX);
					indexData.push(j1 + 1, j1 + countX, j1 + countX + 1);
				}
			}
			
			var vertexBuffer:VertexBuffer3D = context3D.createVertexBuffer(vertexCount, 5);
			vertexBuffer.uploadFromVector(vertexData, 0, vertexCount);
			
			var indexBuffer:IndexBuffer3D = context3D.createIndexBuffer(indexCount);
			indexBuffer.uploadFromVector(indexData, 0, indexCount);
			
			context3D.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context3D.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			
			return indexBuffer;
		}
		
		protected function context3DCreateHandler(event:Event):void
		{
			context3D = stage3D.context3D;
			
			trace(context3D.driverInfo);
			
			context3D.enableErrorChecking = true;
			
			context3D.configureBackBuffer(originalWidth, originalHeight, 0, true);
			context3D.setCulling(Context3DTriangleFace.NONE);
			
			indexBuffer = createPlane(context3D, 50, 50);
			
			texture = context3D.createTexture(512, 512, Context3DTextureFormat.BGRA, false);
			
			context3D.setTextureAt(1, texture);
			
			program = context3D.createProgram();
			program.upload(
				createShader(Context3DProgramType.VERTEX,
					[
						"m44 op, va0, vc0",
						"mov v0, va1"
					]),
				createShader(Context3DProgramType.FRAGMENT,
					[
						"mov ft0, v0",
						"tex ft1, ft0, fs1 <2d,clamp,linear>",		
						"mov oc, ft1"
					]));
			
			context3D.setProgram(program);
			
			stage.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
			stage.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheelHandler);
		}
		
		protected function mouseMoveHandler(ev:MouseEvent):void
		{
			camera3D.position.y = 10 * ev.stageY/stage.stageHeight - 5;
		}
		
		protected function mouseWheelHandler(ev:MouseEvent):void
		{
			cameraDistance -= ev.delta;
		}
		
		protected function enterFrameHandler(event:Event):void
		{
			snapshot.draw(video, snapshotTransform);
			texture.uploadFromBitmapData(snapshot);
			
			var time:Number = getTimer()/1000;
			
			camera3D.position.x = cameraDistance * Math.cos(time);
			camera3D.position.z = cameraDistance * Math.sin(time);
			
			context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, camera3D.getMatrix(), true);
			context3D.clear();
			context3D.drawTriangles(indexBuffer);
			context3D.present();
		}
	}
}